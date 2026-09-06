////
//  GitMergeReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What Git says about the merge it is in the middle of.
///
/// Asked only while `MERGE_HEAD` exists, because that file is what an unfinished merge is. The
/// answer is the label the Conflict choices carry, so it comes from Git's own refs rather than
/// from the words in `MERGE_MSG`, which are a translated sentence rather than data.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads this from an actor.
nonisolated struct GitMergeReader {
    let git: GitProcess

    /// The status `rev-parse --verify --quiet` exits with when the Ref it was asked about is not
    /// there, which is an answer rather than a failure.
    private static let missingRefExitStatus: Int32 = 1

    /// What the unfinished merge is bringing in, or `nil` when there is no merge to describe.
    ///
    /// Two questions, because Git answers them separately. The abbreviated object ID is the label
    /// that always exists; the Branch is the better one, and Git only has it when a Branch still
    /// points at that Commit. A Branch beats a Remote-tracking Branch of the same Commit for the
    /// same reason the sidebar lists them apart: the local one is the Ref the user chose.
    func mergeHead(inRepositoryAt repositoryURL: URL) async throws -> MergeHead? {
        let objectID: String
        do {
            objectID = try await git.text(
                ["rev-parse", "--short", "--verify", "--quiet", "--end-of-options", "MERGE_HEAD"],
                in: repositoryURL
            )
        } catch RepositoryOpenError.commandFailed(let details)
            where details.exitStatus == Self.missingRefExitStatus {
            return nil
        }
        guard !objectID.isEmpty else {
            return nil
        }

        return MergeHead(
            branch: try await branch(pointingAtMergeHeadIn: repositoryURL),
            objectID: objectID
        )
    }

    /// The best name Git has for the merged Commit: a local Branch when one points at it,
    /// otherwise a Remote-tracking Branch, otherwise none.
    ///
    /// Asked as two bounded questions rather than one combined listing. `for-each-ref` sorts by
    /// refname, so a single query would put `refs/heads/z` behind `refs/remotes/origin/a` and
    /// would grow with however many refs happen to sit on that Commit; `--count=1` per namespace
    /// asks for exactly the one answer each is allowed to give.
    private func branch(pointingAtMergeHeadIn repositoryURL: URL) async throws -> String? {
        for namespace in ["refs/heads", "refs/remotes"] {
            let name = try await git.text(
                [
                    "for-each-ref", "--format=%(refname:short)", "--count=1",
                    "--points-at", "MERGE_HEAD", namespace,
                ],
                in: repositoryURL
            )
            if !name.isEmpty {
                return name
            }
        }
        return nil
    }
}
