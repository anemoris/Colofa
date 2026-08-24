////
//  AuthenticationResponse.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What Colofa hands back to the process that asked.
///
/// Cancelling is a real answer rather than the absence of one: the AskPass program exits without
/// writing anything, and Git or OpenSSH ends the operation itself. Nothing here is ever stored.
nonisolated enum AuthenticationResponse: Equatable, Sendable {
    case answer(String)
    case cancelled

    /// The text handed to the waiting process, or `nil` when there is none to hand over.
    var text: String? {
        guard case .answer(let text) = self else {
            return nil
        }
        return text
    }
}
