////
//  StashWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
@testable import Colofa

let stashRepositoryURL = URL(filePath: "/tmp/Stash Store")

/// A Repository holding work worth saving: one Staged Change, one unstaged tracked change, and
/// one untracked file.
///
/// Kept apart from the other fixtures because a Stash needs each kind of eligible work separable:
/// what Keep Staged Changes and Include Untracked Files do is only visible when the index and the
/// untracked file are distinct from the tracked change beside them.
func stashRepository(
    at url: URL = stashRepositoryURL,
    head: RepositoryHead = .branch("main"),
    stagedChanges: [RepositoryChange] = [RepositoryChange(path: "staged.swift", kind: .added)],
    unstagedChanges: [RepositoryChange] = [
        RepositoryChange(path: "diff.txt", kind: .modified),
        RepositoryChange(path: "notes.txt", kind: .untracked),
    ],
    operation: RepositoryOperation? = nil
) -> RepositorySnapshot {
    repository(
        at: url,
        head: head,
        headCommit: RepositoryHeadCommit(objectID: "head", summary: "Fixture commit"),
        operation: operation,
        localBranches: ["main"],
        stagedChanges: stagedChanges,
        unstagedChanges: unstagedChanges
    )
}

/// One entry the fixture's Git reports, with only the fields a test cares about.
func stashEntry(
    selector: String = "stash@{0}",
    objectID: String = "stash-newest",
    baseObjectID: String = "base",
    untrackedObjectID: String? = nil,
    message: String = "On main: parser rewrite",
    authoredDate: Date = Date(timeIntervalSince1970: 1_700_000_000)
) -> Stash {
    Stash(
        selector: selector,
        objectID: objectID,
        abbreviatedObjectID: String(objectID.suffix(7)),
        baseObjectID: baseObjectID,
        untrackedObjectID: untrackedObjectID,
        message: message,
        authorName: "Fixture Author",
        authorEmail: "fixture@example.invalid",
        authoredDate: authoredDate
    )
}

/// What one Stash saved, built from paths rather than from a full `DiffFileSummary` each time.
func stashDetail(
    objectID: String = "stash-newest",
    tracked: [String] = ["diff.txt"],
    untracked: [String] = []
) -> StashDetail {
    StashDetail(
        objectID: objectID,
        files: tracked.map { stashFile($0, isUntracked: false) }
            + untracked.map { stashFile($0, isUntracked: true) }
    )
}

func stashFile(_ path: String, isUntracked: Bool) -> StashFile {
    StashFile(
        summary: DiffFileSummary(
            oldPath: nil,
            newPath: path,
            stats: DiffStats(additions: 2, deletions: 1)
        ),
        isUntracked: isUntracked
    )
}
