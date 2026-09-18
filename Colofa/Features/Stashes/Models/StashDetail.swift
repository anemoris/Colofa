////
//  StashDetail.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What one selected Stash is read for beyond its row: the paths it saved.
///
/// Kept apart from `Stash` for the reason a Commit's changed paths are kept apart from its row —
/// the list carries every entry, and counting changed lines is a second command per entry.
nonisolated struct StashDetailRequest: Equatable, Sendable {
    let repositoryURL: URL
    let objectID: String
    let baseObjectID: String
    let untrackedObjectID: String?

    /// What the Stash changed in files Git was already tracking, compared against the Commit it
    /// was saved from. This is exactly what `git stash show` reports.
    var trackedSource: DiffSource {
        .commit(objectID: objectID, parentObjectID: baseObjectID)
    }

    /// The untracked files the Stash saved, or `nil` when it saved none.
    ///
    /// Git gives them a Commit with no parent, so it is read the way a root Commit is: everything
    /// it introduced. Comparing that Commit against the base instead would need every one of its
    /// paths in the pathspec — a list with no bound — to stop Git reporting every tracked file as
    /// deleted.
    var untrackedSource: DiffSource? {
        untrackedObjectID.map { .commit(objectID: $0, parentObjectID: nil) }
    }
}

nonisolated struct StashDetail: Equatable, Sendable {
    let objectID: String

    /// Tracked changes first, then the untracked files the Stash saved, which is the order
    /// `git stash show --include-untracked` reports them in.
    let files: [StashFile]

    func file(_ id: String) -> StashFile? {
        files.first { $0.id == id }
    }
}
