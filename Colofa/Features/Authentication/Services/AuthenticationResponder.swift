////
//  AuthenticationResponder.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Whoever answers an Authentication Request while a command runs.
///
/// A function rather than a protocol for the same reason `RepositoryService` is one: the Store
/// supplies the answer the user typed, a test supplies a fixed one, and a command that must never
/// ask supplies `refusing`.
nonisolated struct AuthenticationResponder: Sendable {

    /// Suspends until the question is answered or the prompt is cancelled.
    let respond: @Sendable (AuthenticationRequest) async -> AuthenticationResponse

    init(respond: @escaping @Sendable (AuthenticationRequest) async -> AuthenticationResponse) {
        self.respond = respond
    }

    /// Answers nothing, which ends the command that asked. Used where there is no window to ask
    /// in — and as the safe default, because a command that silently waits for an answer nobody
    /// can give is the state Colofa exists to prevent.
    static let refusing = Self { _ in .cancelled }
}
