////
//  AuthenticationFailure.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// A command that failed over the answer to an Authentication Request rather than over anything
/// it was asked to do.
///
/// Decided while the command runs whenever Colofa's own channel already knows the answer, and
/// read out of Git's and OpenSSH's own output otherwise: a remote nobody could reach and a host
/// whose key no longer matches both end as one failed `git fetch`, and only one of them is a
/// reason to stop trusting the connection.
///
/// The two sources are not interchangeable. Prompt text is redacted out of what a command
/// reports, so a refusal Colofa decided from a prompt cannot be recognized again in the output
/// that survives it — it travels as this value instead. Output remains the only source for a
/// refusal that never reached a prompt at all, which is how OpenSSH usually refuses a key it
/// already recorded.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while the Store
/// reads this from a command that ran off it.
nonisolated enum AuthenticationFailure: Equatable, Sendable {

    /// OpenSSH recorded a different key for this host and refused the connection. Colofa offers
    /// no way to continue: the answer that would continue is the answer that accepts whoever is
    /// answering in the host's place, and undoing it means editing `known_hosts` deliberately.
    case changedHostKey

    /// The host's key was never confirmed, so OpenSSH refused to go on.
    case unverifiedHostKey

    /// Git had no credentials and got none, which is where a cancelled or unanswered prompt ends.
    case declinedCredentials

    /// Colofa could not open the channel a question would have travelled over, so the command ran
    /// with no way to reach the user at all.
    ///
    /// - Parameter reason: What stopped the channel from opening, in the system's own words. The
    ///   user can act on "No space left on device"; they can act on nothing at all if the failure
    ///   is reported as the refused credential it was never about.
    case unavailableChannel(reason: String)

    /// What a question nobody answered means for the command that asked it.
    ///
    /// The one classification that does not have to be recognized in anything: the channel knows
    /// which question it refused, so it says so directly.
    static func refusing(_ kind: AuthenticationRequestKind) -> Self {
        switch kind {
        case .changedHostKey: .changedHostKey
        case .newHostKey: .unverifiedHostKey
        case .username, .password, .keyPassphrase, .unrecognized: .declinedCredentials
        }
    }

    /// What `output` says went wrong about authentication, or `nil` when it says nothing about
    /// it.
    static func detect(in output: String) -> Self? {
        // Checked first: a changed key also fails host key verification, and the general answer
        // would hide the specific one.
        if output.contains("HOST IDENTIFICATION HAS CHANGED")
            || output.contains("host key has just been changed") {
            return .changedHostKey
        }
        if output.contains("Host key verification failed") {
            return .unverifiedHostKey
        }
        if output.contains("could not read Username")
            || output.contains("could not read Password")
            || output.contains("terminal prompts disabled") {
            return .declinedCredentials
        }
        return nil
    }

    var title: LocalizedStringResource {
        switch self {
        case .changedHostKey: .authenticationHostKeyChangedTitle
        case .unverifiedHostKey: .authenticationHostKeyUnverifiedTitle
        case .declinedCredentials: .authenticationDeclinedTitle
        case .unavailableChannel: .authenticationChannelUnavailableTitle
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .changedHostKey: .authenticationHostKeyChangedMessage
        case .unverifiedHostKey: .authenticationHostKeyUnverifiedMessage
        case .declinedCredentials: .authenticationDeclinedMessage
        case .unavailableChannel(let reason): .authenticationChannelUnavailableMessage(reason)
        }
    }
}
