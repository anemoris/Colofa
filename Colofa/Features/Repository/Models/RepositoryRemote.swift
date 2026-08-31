////
//  RepositoryRemote.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct RepositoryRemote: Equatable, Identifiable, Sendable {
    let name: String

    /// Exactly what Git reported. Never shown: a remote URL is ordinary configuration and may
    /// spell out `https://user:token@host`, so only `displayURL` reaches the screen.
    let url: String

    var id: String { name }

    /// The same address with any password removed.
    ///
    /// Shared with the Push confirmation rather than masked a second way here: the two are the
    /// same secret in the same kind of address, and one of them deciding differently is how a
    /// token ends up on screen.
    var displayURL: String {
        PushDestination.masking(url)
    }
}
