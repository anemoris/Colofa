////
//  UITestingRepositoryService+Staging.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

#if DEBUG
import Foundation

/// How the stubbed backend projects one path between the Staged and unstaged halves of the
/// Repository it reports.
///
/// Grouped apart from the fixture itself because it is the one piece of real Git behavior the
/// stub reproduces rather than announces: Stage, Unstage, Discard, and Mark as Resolved all end
/// up here, and each has to leave the two lists the way Git would.
extension UITestingRepositoryService {
    func updateChanges(for command: [String], in snapshot: RepositorySnapshot) {
        let paths = command.drop { $0 != "--" }.dropFirst()
        var staged = snapshot.stagedChanges
        var unstaged = snapshot.unstagedChanges
        let action = command.drop { $0 == "--literal-pathspecs" }.first
        if action == "add" {
            let changes = unstaged.filter { change in
                change.gitPathspecs.contains { paths.contains($0) }
            }
            unstaged.removeAll { changes.contains($0) }
            // Git records whatever the file holds right now, so Mark as Resolved leaves an
            // ordinary Staged modification rather than a Conflict that is somehow also staged.
            for change in changes.map(resolved) where !staged.contains(change) {
                staged.append(change)
            }
        } else if command.contains("--worktree") {
            // A Discard restores the working tree from the index, so the unstaged projection of
            // the path goes and whatever is staged for it stays exactly where it was.
            unstaged.removeAll { change in
                !change.isConflict
                    && !change.isUntracked
                    && change.gitPathspecs.contains { paths.contains($0) }
            }
        } else if action == "restore" || action == "rm" {
            let changes = staged.filter { change in
                change.gitPathspecs.contains { paths.contains($0) }
            }
            staged.removeAll { changes.contains($0) }
            for change in changes where !unstaged.contains(change) {
                unstaged.append(change)
            }
        }

        self.snapshot = replacing(
            in: snapshot,
            staged: staged.sorted { $0.path < $1.path },
            unstaged: unstaged.sorted(by: changeOrder)
        )
    }

    private func resolved(_ change: RepositoryChange) -> RepositoryChange {
        change.isConflict
            ? RepositoryChange(path: change.path, kind: .modified)
            : change
    }

    private func changeOrder(_ lhs: RepositoryChange, _ rhs: RepositoryChange) -> Bool {
        if lhs.isConflict != rhs.isConflict {
            return lhs.isConflict
        }
        return lhs.path < rhs.path
    }
}
#endif
