////
//  StashDetailLoadState.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What the detail pane is showing for the selected Stash.
nonisolated enum StashDetailLoadState: Equatable, Sendable {
    case loading
    case loaded(StashDetail)
    case failed(RepositoryOpenError)

    var detail: StashDetail? {
        if case .loaded(let detail) = self {
            return detail
        }
        return nil
    }
}
