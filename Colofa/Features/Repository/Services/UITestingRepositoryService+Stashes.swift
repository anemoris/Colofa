////
//  UITestingRepositoryService+Stashes.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The stubbed Stash reads and the one mutation that changes them.
///
/// The fixture saves a real-shaped entry and leaves a truthful working tree behind it, so a UI
/// test asserts the same relationship the app has with Git: what a Stash took is exactly what the
/// Repository stops reporting.
extension UITestingRepositoryService {
    func stashes(in repositoryURL: URL) -> [Stash] {
        guard currentSnapshot(at: repositoryURL) != nil else {
            return []
        }
        return stashEntries
    }

    func stashDetail(_ request: StashDetailRequest) -> StashDetail {
        UITestingStashes.detail(for: request)
    }

    /// Saves one Stash, or `nil` when `command` is not one.
    ///
    /// - Throws: The refusal `--ui-testing-stash-failure` asks for, which is how the sheet's own
    ///   failure state is driven.
    func stashMutation(
        _ command: [String],
        in snapshot: RepositorySnapshot
    ) throws -> RepositorySnapshot? {
        guard command.first == "stash" else {
            return nil
        }
        if arguments.contains(UITestingArgument.stashFailure) {
            throw RepositoryOpenError.commandFailed(
                GitFailureDetails(
                    command: "git stash push",
                    output: "error: unable to write new index file"
                )
            )
        }

        let keepsStagedChanges = command.contains("--keep-index")
        let includesUntrackedFiles = command.contains("--include-untracked")
        let message = command.firstIndex(of: "-m").map { index in
            command.index(after: index) < command.endIndex ? command[command.index(after: index)] : ""
        } ?? ""

        stashEntries = UITestingStashes.renumbered(
            [
                UITestingStashes.created(
                    message: message,
                    includesUntrackedFiles: includesUntrackedFiles,
                    in: snapshot
                ),
            ] + stashEntries
        )

        // What the Stash took is what the Repository stops reporting. Keep Staged Changes leaves
        // the index alone, a path Git was never tracking only goes when it was asked for, and a
        // submodule's own working tree is never touched.
        return replacing(
            in: snapshot,
            staged: keepsStagedChanges ? nil : [],
            unstaged: snapshot.unstagedChanges.filter {
                $0.isSubmodule || ($0.isUntracked && !includesUntrackedFiles)
            }
        )
    }
}
#endif
