////
//  GitRemoteReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The two read-only questions Fetch asks Git: which remotes a Fetch of every remote is allowed
/// to contact, and which local tags a remote's tags would have replaced.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads these from an actor.
nonisolated struct GitRemoteReader {
    let git: GitProcess

    /// Which remotes Git's own configuration excludes from a Fetch of every remote.
    func skippedRemotes(in repositoryURL: URL) async throws -> Set<String> {
        try GitSkipFetchAllParser.parse(
            try await git.dataAllowingNoMatches(
                [
                    "config", "--null", "--get-regexp", "--type=bool",
                    "^remote\\..*\\.skipfetchall$",
                ],
                in: repositoryURL
            )
        )
    }

    /// Which tag names the remote and the Repository disagree about.
    ///
    /// Asked only after Git has already refused a Fetch Tags, so it contacts the remote a second
    /// time rather than as part of every Fetch.
    func tagConflicts(_ request: TagConflictRequest) async throws -> TagFetchConflict {
        TagFetchConflict.evaluate(
            remoteTags: try GitTagReferenceParser.parseRemote(
                try await git.data(
                    ["ls-remote", "--tags", "--refs", "--", request.remote],
                    in: request.repositoryURL
                )
            ),
            localTags: try GitTagReferenceParser.parseLocal(
                try await git.data(
                    ["for-each-ref", "--format=%(objectname)%00%(refname)", "refs/tags"],
                    in: request.repositoryURL
                )
            )
        )
    }
}
