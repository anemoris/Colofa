////
//  StashLoadState.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What the Stashes pane is showing for the open Repository.
nonisolated enum StashLoadState: Equatable, Sendable {
    case loading
    case loaded([Stash])
    case failed(RepositoryOpenError)

    var stashes: [Stash]? {
        if case .loaded(let stashes) = self {
            return stashes
        }
        return nil
    }
}
