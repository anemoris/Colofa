////
//  AuthenticationRequest.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One question Git or OpenSSH asked while a command of Colofa's was running.
///
/// It exists only while that command is waiting for it. Nothing about it is written to the app's
/// preferences or to any store Colofa owns: whether the answer survives is decided by the
/// credential helper, Keychain integration, or SSH agent the user already configured.
nonisolated struct AuthenticationRequest: Equatable, Identifiable, Sendable {

    /// Identifies this question for as long as it is unanswered. It is what makes an answer
    /// belong to the prompt it was typed into rather than to whichever prompt is open when it
    /// arrives.
    let id: UUID

    let kind: AuthenticationRequestKind

    /// Whom the question is about, exactly as Git or OpenSSH named it: an HTTPS remote's URL, an
    /// SSH host, or the path of a private key. `nil` when the question named nobody.
    ///
    /// Shown verbatim, because it is Git's own text rather than Colofa's copy.
    let subject: String?

    /// The question exactly as it was asked, kept so the user reads what the tool asked rather
    /// than Colofa's guess at it.
    ///
    /// This is prompt text, so it is redacted out of every failure Colofa reports: it can carry
    /// an account name, and a diagnostic is not the place to repeat one.
    let prompt: String

    init(id: UUID = UUID(), kind: AuthenticationRequestKind, subject: String?, prompt: String) {
        self.id = id
        self.kind = kind
        self.subject = subject
        self.prompt = prompt
    }

    /// The fingerprint the user is being asked to recognize, or `nil` when this is not a host
    /// key question.
    var fingerprint: String? {
        guard case .newHostKey(let fingerprint) = kind else {
            return nil
        }
        return fingerprint
    }

    /// Whether this question can be answered at all.
    ///
    /// A new host with no fingerprint to compare has nothing to confirm, so it is refused for the
    /// same reason a changed key is: agreeing would be agreeing to something unread.
    var isAnswerable: Bool {
        if kind.isRefused {
            return false
        }
        if case .newHostKey(let fingerprint) = kind {
            return fingerprint?.isEmpty == false
        }
        return true
    }
}
