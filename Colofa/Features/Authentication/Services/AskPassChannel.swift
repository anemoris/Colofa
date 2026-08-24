////
//  AskPassChannel.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One command's Authentication Request channel, or the reason it has none.
///
/// A command still runs without a channel. Git then finds no AskPass program, no terminal it is
/// allowed to prompt on, and fails saying so, which is the right outcome for a remote that needed
/// a secret and no outcome at all for the many that need none. Refusing to contact a remote
/// because a socket could not be created would be worse than either.
///
/// What must not happen is that failure reading as a credential the user refused. So the reason
/// the channel never opened is kept rather than dropped, and explains the failure if one arrives.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: a channel belongs
/// to a command that runs off it.
nonisolated struct AskPassChannel: Sendable {

    /// What relays this command's questions, or `nil` when it has nothing to relay them over.
    let bridge: GitAskPassBridge?

    /// Why this command has no channel, when that is something the user has to be told. `nil`
    /// when a channel was opened, and when the app ships no AskPass program at all.
    let unavailability: AuthenticationFailure?

    /// Opens the channel one command's questions travel over.
    ///
    /// - Parameter helperURL: The executable Git and OpenSSH run to ask a question, or `nil` in an
    ///   app built without one. That is not a condition of this command and nothing the user could
    ///   act on, so it is not carried as a failure: Git then behaves exactly as it does for any
    ///   other client that has no AskPass program.
    static func opened(
        pointingAt helperURL: URL?,
        answeredBy responder: AuthenticationResponder
    ) -> Self {
        guard let helperURL else {
            return Self(bridge: nil, unavailability: nil)
        }
        do {
            let bridge = try GitAskPassBridge(helperURL: helperURL, responder: responder)
            return Self(bridge: bridge, unavailability: nil)
        } catch {
            return Self(
                bridge: nil,
                unavailability: .unavailableChannel(reason: error.localizedDescription)
            )
        }
    }

    /// Ends the channel and removes the socket behind it. Callable more than once, and on a
    /// command that never had one.
    func stop() {
        bridge?.stop()
    }

    /// `git` with this channel in its environment, and with whatever the channel learns registered
    /// for redaction before it can reach a failure message.
    func authenticating(_ git: GitProcess) -> GitProcess {
        guard let bridge else {
            return git
        }
        return GitProcess(
            executableURL: git.executableURL,
            environment: git.environment.merging(bridge.environment) { _, asked in asked },
            secrets: bridge.secrets,
            // The channel answers this command's own programs. Which processes those are is only
            // knowable once the command is one, so it is told rather than asked.
            didLaunch: { bridge.commandLaunched(as: $0) }
        )
    }

    /// `error`, carrying what this channel already knows about why the command failed.
    ///
    /// Only a command Git itself refused is explained. Anything else — a cancellation, a Git that
    /// could not be found — did not fail over a question, and a channel says nothing about it.
    func explaining(_ error: any Error) -> any Error {
        guard let repositoryError = error as? RepositoryOpenError,
              case .commandFailed(let details) = repositoryError,
              let failure = explanation(for: details) else {
            return error
        }
        return RepositoryOpenError.commandFailed(details.reporting(failure))
    }

    /// What this channel can say about a command that failed, or `nil` when it can say nothing.
    ///
    /// The two things a channel knows are not equally conclusive. A bridge that refused a question
    /// knows the command failed over that question, because the command asked and was told no.
    /// A channel that never opened knows only that it could not have answered one, which
    /// explains a failure only where Git's own words say an unanswered question is what stopped
    /// it. Without that condition the first unreachable host, refused tag, or rejected push on a
    /// machine whose channel cannot open would be reported as an authentication problem the
    /// command never had, and the reason it actually failed would survive only in the details.
    private func explanation(for details: GitFailureDetails) -> AuthenticationFailure? {
        if let refused = bridge?.authenticationFailure {
            return refused
        }
        guard let unavailability,
              let detected = AuthenticationFailure.detect(in: details.output),
              // A key that no longer matches is refused whether or not anybody could have been
              // asked, so the missing channel explains nothing about it.
              detected != .changedHostKey else {
            return nil
        }
        return unavailability
    }
}
