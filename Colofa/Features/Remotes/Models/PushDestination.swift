////
//  PushDestination.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The one address a Push to a remote actually writes to, read before the confirmation opens.
///
/// It exists because a remote name is not a destination. Git resolves the name when the command
/// runs, `remote.<name>.pushurl` may name several addresses at once, and neither is visible in
/// `origin/main`. Reading the address separately is what lets Colofa show what it is about to
/// write to, and refuse the configurations it cannot show honestly.
nonisolated struct PushDestination: Equatable, Sendable {

    /// Exactly what Git reported, which is the value a later read is compared against. Never
    /// shown: it may carry a password.
    let url: String

    nonisolated init(_ url: String) {
        self.url = url
    }

    /// The same address with any password removed, which is the only form that reaches the screen.
    ///
    /// The user name is kept, because it is part of which account is writing and Git shows it in
    /// its own messages for the same reason. Only the secret is replaced.
    var display: String {
        Self.masking(url)
    }

    /// What stands in for a password that must not be displayed.
    static let maskedPassword = "••••••"

    /// `url` with the password of a `scheme://user:password@host` address replaced.
    ///
    /// Only that spelling can carry one. Git's scp-like `user@host:path` form has no place to put
    /// a password, and a filesystem path has no authority at all, so both are returned unchanged.
    static func masking(_ url: String) -> String {
        guard let scheme = url.range(of: "://") else {
            return url
        }
        let authority = url[scheme.upperBound...]
        let end = authority.firstIndex(of: "/") ?? authority.endIndex
        // The last `@`, because a user name may contain one — an account spelled as an email
        // address is the ordinary case — while the host may not.
        guard let credentials = authority[..<end].lastIndex(of: "@"),
              let separator = authority[..<credentials].firstIndex(of: ":") else {
            return url
        }
        let password = authority.index(after: separator)..<credentials
        // An address that carries no password is left as it is: writing a mask over nothing would
        // claim a secret is there to hide.
        guard !password.isEmpty else {
            return url
        }
        return url.replacingCharacters(in: password, with: Self.maskedPassword)
    }
}
