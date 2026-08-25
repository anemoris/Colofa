////
//  GitAskPassBridge.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Foundation
import os

/// Relays the questions Git and OpenSSH ask into Colofa, for the length of one command.
///
/// Git and OpenSSH both ask through an AskPass program: an executable they run, hand the question
/// to, and read one line back from. Colofa's is Colofa itself, started again in the AskPass mode
/// `GitAskPassHelper` defines, which connects back here over a local socket in a directory only
/// this user can read.
///
/// This is deliberately the last thing consulted. A configured credential helper, macOS Keychain
/// integration, `ssh-agent`, and the user's OpenSSH configuration all run first and are left
/// exactly as configured; Git reaches an AskPass program only once they have answered nothing.
///
/// A bridge belongs to one command. Its socket, its directory, and the token that addresses it
/// are created when the command starts and destroyed when it ends, so a program from a finished
/// operation — or from anything else on the machine — has nothing to connect to and no token that
/// would be accepted if it did. A program that does hold both is answered only while it is also
/// something this command's own Git ran, so a duplicate of it is not a second chance to ask.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: it serves
/// connections while a Git process runs, off the main actor.
nonisolated final class GitAskPassBridge: Sendable {

    /// What Git and OpenSSH need in their environment to ask through this bridge, merged over the
    /// environment the command would otherwise run with.
    let environment: [String: String]

    /// What this command learned that must not be repeated back in its failure details.
    let secrets: GitSecretRedaction

    private let directoryURL: URL
    private let listener: GitAskPassListener
    private let serveTask: Task<Void, Never>
    private let refusal: AuthenticationRefusal
    private let command: CommandProcess

    /// Why the command this channel belongs to is going to fail, when the channel is what decided
    /// it — a key that changed, a host nobody confirmed, a question nobody answered.
    ///
    /// Read after the command has already failed, and only then: a refusal explains a failure, it
    /// does not predict one.
    var authenticationFailure: AuthenticationFailure? {
        refusal.value
    }

    /// - Parameter helperURL: The executable Git and OpenSSH run to ask a question, which is
    ///   Colofa's own — the AskPass mode is part of the app rather than a second program that
    ///   could be replaced on disk beside it.
    /// - Throws: `POSIXError` or a `CocoaError` when the directory or socket cannot be created.
    init(helperURL: URL, responder: AuthenticationResponder) throws {
        // Short, because a local socket address holds far less than a file system path does, and
        // the temporary directory it sits in is already most of that budget.
        let name = String(UInt32.random(in: .min ... .max), radix: 36)
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: "colofa-\(name)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: false,
            // Readable only by this user: the socket inside decides which process may ask Colofa
            // for a secret, so who can reach it is part of that decision.
            attributes: [.posixPermissions: 0o700]
        )
        let socketURL = directoryURL.appending(path: "s")
        let token = UUID().uuidString

        let listener: GitAskPassListener
        do {
            listener = try GitAskPassListener(socketPath: socketURL.normalizedFilePath)
        } catch {
            try? FileManager.default.removeItem(at: directoryURL)
            throw error
        }

        let secrets = GitSecretRedaction()
        let refusal = AuthenticationRefusal()
        let command = CommandProcess()
        let helperPath = helperURL.normalizedFilePath
        self.directoryURL = directoryURL
        self.listener = listener
        self.secrets = secrets
        self.refusal = refusal
        self.command = command
        environment = [
            "GIT_ASKPASS": helperPath,
            "SSH_ASKPASS": helperPath,
            // OpenSSH otherwise only asks a program when it has no terminal of its own, and
            // decides that from a display it will never find here.
            "SSH_ASKPASS_REQUIRE": "force",
            GitAskPassSocket.socketVariable: socketURL.normalizedFilePath,
            GitAskPassSocket.tokenVariable: token,
        ]
        let channel = Channel(
            token: token,
            command: command,
            secrets: secrets,
            refusal: refusal,
            responder: responder
        )
        serveTask = Task.detached {
            for await connection in listener.connections {
                await Self.serve(connection, on: channel)
            }
        }
    }

    deinit {
        stop()
    }

    /// Tells the channel what process the command it belongs to is running as.
    ///
    /// Called once, as soon as Git has a process at all. Everything Git asks through is something
    /// Git ran, so from here on a connection is answered only when it came from this command's own
    /// process tree — the token alone would also address a program that merely holds this
    /// command's environment.
    func commandLaunched(as processID: pid_t) {
        command.record(processID)
    }

    /// Ends the channel: nothing more is accepted, anything still waiting for an answer stops
    /// waiting, and the socket is removed from disk.
    ///
    /// Called when the command ends however it ended — finished, failed, or cancelled — so no
    /// channel outlives the process it belonged to. Callable more than once.
    func stop() {
        serveTask.cancel()
        listener.stop()
        try? FileManager.default.removeItem(at: directoryURL)
    }

    /// Everything serving one connection needs, which is everything about this channel that
    /// outlives a single question.
    private struct Channel: Sendable {
        let token: String
        let command: CommandProcess
        let secrets: GitSecretRedaction
        let refusal: AuthenticationRefusal
        let responder: AuthenticationResponder
    }

    private static func serve(
        _ connection: GitAskPassConnection,
        on channel: Channel
    ) async {
        // Asked before anything is read: a program this command did not start has no question
        // worth reading, and refusing it here is refusing it before it has said anything.
        guard invoked(connection, by: channel.command),
              let data = await connection.question(limit: GitAskPassMessage.maximumRequestSize),
              let message = GitAskPassMessage.parseRequest(data),
              message.token == channel.token else {
            await connection.answer(GitAskPassMessage.reply(.cancelled))
            return
        }

        let request = AuthenticationPromptParser.request(for: message.prompt)
        // Every question is redacted out of what this command reports, including the ones Colofa
        // answers itself. A question names whom a secret belongs to, and a host key question
        // names a host, an address, and a fingerprint; a diagnostic is not where any of that
        // belongs. What a refusal was about travels as state instead, so explaining it never
        // depends on reading back text that is deliberately no longer there.
        channel.secrets.record(request.prompt)
        guard request.isAnswerable else {
            channel.refusal.record(.refusing(request.kind))
            await connection.answer(GitAskPassMessage.reply(.cancelled))
            return
        }

        let response = await channel.responder.respond(request)
        guard let text = response.text else {
            channel.refusal.record(.refusing(request.kind))
            await connection.answer(GitAskPassMessage.reply(.cancelled))
            return
        }
        channel.secrets.record(text)
        await connection.answer(GitAskPassMessage.reply(response))
    }

    /// Whether `connection` came from a program the command this channel belongs to invoked.
    ///
    /// The token addresses one operation; it does not establish that whoever presents it is a
    /// program that operation ran. Descent does: Git and OpenSSH ask through AskPass programs they
    /// start themselves, so a connection from outside this command's process tree is a duplicate
    /// or a stranger holding its environment rather than the question it was meant to carry.
    ///
    /// Allowed while there is no process to compare against. That window closes the moment Git is
    /// running, and until it does nothing could have taken an environment from a process that does
    /// not exist yet.
    private static func invoked(
        _ connection: GitAskPassConnection,
        by command: CommandProcess
    ) -> Bool {
        guard let commandProcessID = command.identifier else {
            return true
        }
        guard let peerProcessID = connection.peerProcessID else {
            return false
        }
        return ProcessAncestry.descends(peerProcessID, from: commandProcessID)
    }
}

/// What process the command a channel belongs to is running as, written once it starts and read by
/// every connection that arrives afterwards.
///
/// Declared alongside the bridge for the same reason a refusal is: it carries one value across the
/// queue it was written on and does nothing else.
private nonisolated final class CommandProcess: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: pid_t?.none)

    var identifier: pid_t? {
        storage.withLock { $0 }
    }

    func record(_ processID: pid_t) {
        storage.withLock { $0 = processID }
    }
}

/// The one decision a channel makes about the command it belongs to, written while it serves and
/// read once that command has failed.
///
/// Declared alongside the bridge because it carries a decision off the queue it was made on and
/// does nothing else. The first refusal is kept: it is the one that ended the command, and a
/// question refused afterwards explains nothing the user needs.
private nonisolated final class AuthenticationRefusal: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: AuthenticationFailure?.none)

    var value: AuthenticationFailure? {
        storage.withLock { $0 }
    }

    func record(_ failure: AuthenticationFailure) {
        storage.withLock { stored in
            stored = stored ?? failure
        }
    }
}
