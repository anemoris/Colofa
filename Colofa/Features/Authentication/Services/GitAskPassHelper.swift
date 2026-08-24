////
//  GitAskPassHelper.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Foundation

/// Colofa running as the AskPass program Git and OpenSSH invoke.
///
/// The bridge points `GIT_ASKPASS` and `SSH_ASKPASS` at Colofa's own executable, so this is the
/// same binary started again with nothing but a question to relay. It runs before any window
/// exists and exits before one could: `main.swift` consults this first, and the app itself never
/// starts in this mode.
///
/// Bundling the bridge inside the app rather than beside it means there is no second executable
/// to be replaced, moved, or invoked on its own. Everything that decides whether a question is
/// answered — the socket, the token, the prompt — arrives from the environment of the one Git
/// command that created them.
///
/// It keeps nothing. The answer is written to standard output for the process that asked, which
/// is the only place it goes.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation, and this runs
/// before any actor exists.
nonisolated struct GitAskPassHelper: Sendable {
    private let socketPath: String
    private let token: String

    /// The AskPass work this process was started to do, or `nil` when it was started to be the
    /// app.
    static func pending(in environment: [String: String]) -> Self? {
        guard let socketPath = environment[GitAskPassSocket.socketVariable],
              let token = environment[GitAskPassSocket.tokenVariable],
              !socketPath.isEmpty, !token.isEmpty else {
            return nil
        }
        return Self(socketPath: socketPath, token: token)
    }

    /// Relays `arguments` as one question and writes the answer to `output`.
    ///
    /// - Returns: What to exit with. A cancelled prompt exits non-zero without writing anything,
    ///   which is how an AskPass program declines — Git and OpenSSH then end the operation
    ///   themselves rather than waiting for a terminal nobody is watching.
    func run(arguments: [String], output: FileHandle = .standardOutput) -> Int32 {
        // Git and OpenSSH each pass the question as a single argument, but neither promises to:
        // joining is what keeps a question that arrived in pieces readable as one.
        let prompt = arguments.dropFirst().joined(separator: " ")
        guard case .answer(let text) = ask(prompt) else {
            return 1
        }
        // Both readers take the first line and drop its terminator, so the answer is written the
        // way they read it. An answer that could not be written is declined rather than delivered
        // empty, because an empty answer is one Git would try to authenticate with.
        do {
            try output.write(contentsOf: Data("\(text)\n".utf8))
        } catch {
            return 1
        }
        return 0
    }

    private func ask(_ prompt: String) -> AuthenticationResponse {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            return .cancelled
        }
        defer { close(descriptor) }

        guard var address = try? GitAskPassSocket.address(for: socketPath),
              GitAskPassSocket.withAddress(&address, { pointer, length in
                  connect(descriptor, pointer, length)
              }) == 0 else {
            return .cancelled
        }

        let request = GitAskPassMessage.request(token: token, prompt: prompt)
        guard Self.write(request, to: descriptor) else {
            return .cancelled
        }
        // Half-closing is what ends the question: the bridge reads until the writing stops rather
        // than counting bytes it was told to expect.
        shutdown(descriptor, SHUT_WR)

        guard let reply = Self.read(from: descriptor) else {
            return .cancelled
        }
        return GitAskPassMessage.parseReply(reply)
    }

    private static func write(_ data: Data, to descriptor: Int32) -> Bool {
        var remaining = data[...]
        while !remaining.isEmpty {
            let written = remaining.withUnsafeBytes { buffer in
                Darwin.write(descriptor, buffer.baseAddress, buffer.count)
            }
            if written < 0 {
                guard errno == EINTR else {
                    return false
                }
                continue
            }
            remaining = remaining.dropFirst(written)
        }
        return true
    }

    /// Reads until the bridge closes the connection, bounded the same way a question is: an
    /// answer larger than that is not one.
    ///
    /// - Returns: The whole answer, or `nil` when it ran over the limit or the connection failed
    ///   before the bridge closed it. Either way what arrived is discarded rather than returned:
    ///   half an answer is still an answer as far as Git is concerned, and it would authenticate
    ///   with it.
    private static func read(from descriptor: Int32) -> Data? {
        var reply = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let count = buffer.withUnsafeMutableBytes { destination in
                Darwin.read(descriptor, destination.baseAddress, destination.count)
            }
            if count < 0 {
                guard errno == EINTR else {
                    return nil
                }
                continue
            }
            guard count > 0 else {
                return reply
            }
            reply.append(contentsOf: buffer[0..<count])
            guard reply.count <= GitAskPassMessage.maximumRequestSize else {
                return nil
            }
        }
    }
}
