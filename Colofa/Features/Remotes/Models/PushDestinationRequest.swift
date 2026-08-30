////
//  PushDestinationRequest.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which remote a Push is about to write to, asked of the Repository it belongs to.
nonisolated struct PushDestinationRequest: Equatable, Sendable {
    let repositoryURL: URL

    /// The remote's own name, which is what Git resolves an address out of. It is a name rather
    /// than an address because a Push is still run by name: that is what keeps Git updating the
    /// remote-tracking Ref afterwards, which pushing to a bare URL does not do.
    let remote: String
}
