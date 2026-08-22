////
//  FetchProgress.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// A Fetch that is running right now, and which remote it is contacting.
///
/// Its presence is what makes the toolbar's Fetch a Cancel: a network command has no bound Colofa
/// can promise, so stopping it has to stay reachable for as long as it runs.
nonisolated struct FetchProgress: Equatable, Sendable {

    /// The remote being contacted, or `nil` while Colofa is still reading which remotes Git
    /// considers eligible.
    let remote: String?

    var description: LocalizedStringResource {
        guard let remote else {
            return .fetchInProgress
        }
        return .fetchingRemote(remote)
    }
}
