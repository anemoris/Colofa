////
//  UITestingStashes.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The Stashes UI tests select with launch arguments, and the shape a newly saved one takes.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `UITestingRepositoryService` builds these from an actor.
nonisolated enum UITestingStashes {
    /// The path every seeded entry reports as saved, which is also the path the Diff fixtures
    /// answer a text patch for.
    static let trackedPath = "diff.txt"

    /// The untracked path the second seeded entry saved, so a Stash carrying one can be read.
    static let untrackedPath = "notes.txt"

    static func seeded(arguments: [String]) -> [Stash] {
        guard arguments.contains(UITestingArgument.stashEntries) else {
            return []
        }
        return [
            stash(
                index: 0,
                objectID: "ui-stash-newest",
                message: "On main: parser rewrite",
                untrackedObjectID: "ui-stash-newest-untracked",
                secondsAgo: 600
            ),
            stash(
                index: 1,
                objectID: "ui-stash-oldest",
                message: "WIP on main: ui-fixture-head Fixture commit",
                untrackedObjectID: nil,
                secondsAgo: 7_200
            ),
        ]
    }

    /// What one `git stash push` adds, described the way Git describes it: a message the user
    /// gave, or the `WIP on <branch>:` line Git writes when they gave none.
    static func created(
        message: String,
        includesUntrackedFiles: Bool,
        in snapshot: RepositorySnapshot
    ) -> Stash {
        let branch = branchName(of: snapshot.head)
        return stash(
            index: 0,
            objectID: "ui-stash-created",
            message: message.isEmpty
                ? "WIP on \(branch): \(snapshot.headCommit?.objectID ?? "") \(summary(of: snapshot))"
                : "On \(branch): \(message)",
            untrackedObjectID: includesUntrackedFiles ? "ui-stash-created-untracked" : nil,
            secondsAgo: 0
        )
    }

    static func detail(for request: StashDetailRequest) -> StashDetail {
        var files = [
            StashFile(
                summary: DiffFileSummary(
                    oldPath: nil,
                    newPath: trackedPath,
                    stats: DiffStats(additions: 3, deletions: 1)
                ),
                isUntracked: false
            ),
        ]
        if request.untrackedObjectID != nil {
            files.append(
                StashFile(
                    summary: DiffFileSummary(
                        oldPath: nil,
                        newPath: untrackedPath,
                        stats: DiffStats(additions: 4, deletions: 0)
                    ),
                    isUntracked: true
                )
            )
        }
        return StashDetail(objectID: request.objectID, files: files)
    }

    /// The same entries readdressed after one was pushed in front of them, which is what Git does
    /// to every Stash below a new one.
    static func renumbered(_ stashes: [Stash]) -> [Stash] {
        stashes.enumerated().map { index, stash in
            Stash(
                selector: selector(index),
                objectID: stash.objectID,
                abbreviatedObjectID: stash.abbreviatedObjectID,
                baseObjectID: stash.baseObjectID,
                untrackedObjectID: stash.untrackedObjectID,
                message: stash.message,
                authorName: stash.authorName,
                authorEmail: stash.authorEmail,
                authoredDate: stash.authoredDate
            )
        }
    }

    private static func stash(
        index: Int,
        objectID: String,
        message: String,
        untrackedObjectID: String?,
        secondsAgo: TimeInterval
    ) -> Stash {
        Stash(
            selector: selector(index),
            objectID: objectID,
            abbreviatedObjectID: String(objectID.suffix(7)),
            baseObjectID: "ui-fixture-head",
            untrackedObjectID: untrackedObjectID,
            message: message,
            authorName: "Fixture Author",
            authorEmail: "fixture@example.invalid",
            authoredDate: Date(timeIntervalSince1970: 1_700_000_000 - secondsAgo)
        )
    }

    private static func selector(_ index: Int) -> String {
        "stash@{\(index)}"
    }

    private static func branchName(of head: RepositoryHead) -> String {
        switch head {
        case .branch(let name), .unbornBranch(let name): name
        case .detached(let objectID): String(objectID.prefix(7))
        }
    }

    private static func summary(of snapshot: RepositorySnapshot) -> String {
        snapshot.headCommit?.summary ?? ""
    }
}
#endif
