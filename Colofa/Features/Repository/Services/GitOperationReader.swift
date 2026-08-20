////
//  GitOperationReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which multi-step operation Git is in the middle of, read from the state files Git itself
/// keeps in the Repository's Git directory.
///
/// There is no plumbing command that answers this in one call, so the files are what Git makes
/// available. Order matters: a rebase leaves both its own directory and, while it applies a
/// patch, an `applying` marker, and a cherry-pick and a revert can each look like the other from
/// a single file alone.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads this from an actor.
nonisolated enum GitOperationReader {
    static func operation(inGitDirectoryAt gitDirectoryURL: URL) -> RepositoryOperation? {
        let fileManager = FileManager.default
        if fileManager.fileExists(
            atPath: gitDirectoryURL.appending(path: "rebase-merge").normalizedFilePath
        ) {
            return .rebase
        }
        let rebaseApplyURL = gitDirectoryURL.appending(path: "rebase-apply")
        if fileManager.fileExists(atPath: rebaseApplyURL.normalizedFilePath) {
            return fileManager.fileExists(
                atPath: rebaseApplyURL.appending(path: "applying").normalizedFilePath
            ) ? .am : .rebase
        }
        if fileManager.fileExists(
            atPath: gitDirectoryURL.appending(path: "CHERRY_PICK_HEAD").normalizedFilePath
        ) {
            return .cherryPick
        }
        if fileManager.fileExists(
            atPath: gitDirectoryURL.appending(path: "MERGE_HEAD").normalizedFilePath
        ) {
            return .merge
        }
        if fileManager.fileExists(
            atPath: gitDirectoryURL.appending(path: "REVERT_HEAD").normalizedFilePath
        ) {
            return .revert
        }
        return nil
    }
}
