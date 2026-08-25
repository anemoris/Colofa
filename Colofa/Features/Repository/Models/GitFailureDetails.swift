////
//  GitFailureDetails.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct GitFailureDetails: Equatable, Sendable {
    let command: String
    let output: String
    let exitStatus: Int32?

    /// What the command already knew about why it failed, when it failed over an Authentication
    /// Request rather than over what it was asked to do.
    ///
    /// Carried rather than recognized later: `output` has every prompt redacted out of it by the
    /// time anybody reads it, so a refusal Colofa decided from a prompt is no longer legible
    /// there. `nil` when the command reached no prompt, which leaves `output` the only source.
    let authenticationFailure: AuthenticationFailure?

    nonisolated init(
        command: String,
        output: String,
        exitStatus: Int32? = nil,
        authenticationFailure: AuthenticationFailure? = nil
    ) {
        self.command = command
        self.output = output
        self.exitStatus = exitStatus
        self.authenticationFailure = authenticationFailure
    }

    /// The same details, reporting `failure` as what the command failed over.
    nonisolated func reporting(_ failure: AuthenticationFailure) -> Self {
        Self(
            command: command,
            output: output,
            exitStatus: exitStatus,
            authenticationFailure: failure
        )
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.command == rhs.command
            && lhs.output == rhs.output
            && lhs.exitStatus == rhs.exitStatus
            && lhs.authenticationFailure == rhs.authenticationFailure
    }
}
