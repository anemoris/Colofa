////
//  DiffLoadState.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What the Diff pane is showing for the current selection.
///
/// Every case replaces the previous one outright, so a selection that changed or disappeared can
/// never leave the last patch on screen.
nonisolated enum DiffLoadState: Equatable, Sendable {
    case loading
    case loaded(Diff)
    case confirmationRequired(DiffSummary)
    case beyondHardLimit(DiffSummary)
    /// An unmerged path. Git describes it as a combined Diff of every side, which is not a review
    /// Colofa can honestly present before the Conflict is resolved.
    case conflicted
    case failed(RepositoryOpenError)
}
