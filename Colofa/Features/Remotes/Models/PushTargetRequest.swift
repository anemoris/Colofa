////
//  PushTargetRequest.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which Branch a Push is about, asked of the Repository it belongs to.
nonisolated struct PushTargetRequest: Equatable, Sendable {
    let repositoryURL: URL

    /// The current Branch's own name, never a Ref expression. A Push writes to a remote, so what
    /// it is about must be a name the user can read back in the confirmation rather than
    /// something Git resolves differently later.
    let branch: String
}
