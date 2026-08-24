////
//  UITestingAuthentication.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The questions the stubbed backend asks, so a UI test can drive every Authentication Request
/// without a remote, a key, or a network.
///
/// The prompts are written the way Git and OpenSSH write them, so a UI test exercises the real
/// parser rather than a shape invented for testing.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` reads these from an actor.
nonisolated enum UITestingAuthentication {
    static let remoteURL = "https://example.invalid/Colofa.git"
    static let keyPath = "/Users/colofa/.ssh/id_ed25519"
    static let host = "example.invalid"
    static let fingerprint = "SHA256:0oIfXeSKQ5wPq7nT2m8fCk4vJb1yWx9AZs6EdLuGhRq"

    /// The question this fixture's Git asks, or `nil` when it asks nothing at all.
    static func prompt(arguments: [String]) -> String? {
        if arguments.contains(UITestingArgument.authenticationUsername) {
            return "Username for '\(remoteURL)': "
        }
        if arguments.contains(UITestingArgument.authenticationPassword) {
            return "Password for '\(remoteURL)': "
        }
        if arguments.contains(UITestingArgument.authenticationPassphrase) {
            return "Enter passphrase for key '\(keyPath)': "
        }
        if arguments.contains(UITestingArgument.authenticationHostKey) {
            return newHostPrompt
        }
        if arguments.contains(UITestingArgument.authenticationHostKeyChanged) {
            return changedHostPrompt
        }
        if arguments.contains(UITestingArgument.authenticationUnrecognized) {
            return unrecognizedPrompt
        }
        if arguments.contains(UITestingArgument.authenticationLongPrompt) {
            return longUnrecognizedPrompt
        }
        return nil
    }

    static let unrecognizedPrompt = "Colofa fixture asks something nobody classified:"

    /// A question as long as the channel will carry one. A prompt Colofa did not write is only
    /// bounded by what the AskPass channel accepts, so the sheet that shows it has to stay a
    /// sheet the user can answer at that size.
    static let longUnrecognizedPrompt = (
        [unrecognizedPrompt] + (1...120).map {
            "Line \($0) of a question that went on for far longer than any prompt should."
        }
    ).joined(separator: "\n")

    static let newHostPrompt = """
        The authenticity of host '\(host) (203.0.113.9)' can't be established.
        ED25519 key fingerprint is \(fingerprint).
        This key is not known by any other names.
        Are you sure you want to continue connecting (yes/no/[fingerprint])?
        """

    static let changedHostPrompt = """
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        Are you sure you want to continue connecting (yes/no/[fingerprint])?
        """

    /// What Git writes when a question was refused rather than answered, with the question itself
    /// already redacted out of it — which is how the real channel reports a refusal, and why what
    /// the refusal was about has to travel as `AuthenticationFailure` rather than as text.
    static func refusal(of kind: AuthenticationRequestKind) -> String {
        switch kind {
        case .changedHostKey:
            """
            Host key verification failed.
            fatal: Could not read from remote repository.
            """
        case .newHostKey:
            """
            Host key verification failed.
            fatal: Could not read from remote repository.
            """
        case .username, .password, .keyPassphrase, .unrecognized:
            """
            fatal: could not read Password for '\(remoteURL)': terminal prompts disabled
            """
        }
    }
}
#endif
