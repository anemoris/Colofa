////
//  RepositorySnapshotGitDirectoryTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Covers the rule the inspector uses to decide whether the Git directory earns a row of its own.
struct RepositorySnapshotGitDirectoryTests {

    private func snapshot(root: String, gitDirectory: String) -> RepositorySnapshot {
        RepositorySnapshot(
            name: URL(filePath: root, directoryHint: .isDirectory).lastPathComponent,
            rootURL: URL(filePath: root, directoryHint: .isDirectory),
            gitDirectoryURL: URL(filePath: gitDirectory, directoryHint: .isDirectory),
            head: .branch("main")
        )
    }

    @Test
    func ordinaryRepositoryHidesItsGitDirectory() {
        let repository = snapshot(
            root: "/Users/mia/Developer/Colofa",
            gitDirectory: "/Users/mia/Developer/Colofa/.git"
        )
        #expect(!repository.hasSeparateGitDirectory)
    }

    /// A linked worktree keeps its administrative files under the main Repository, so the two
    /// paths genuinely differ and the row is the only thing that says so.
    @Test
    func worktreeShowsItsGitDirectory() {
        let repository = snapshot(
            root: "/Users/mia/Developer/colofa-release",
            gitDirectory: "/Users/mia/Developer/Colofa/.git/worktrees/release"
        )
        #expect(repository.hasSeparateGitDirectory)
    }

    @Test
    func separateGitDirectoryShowsItsGitDirectory() {
        let repository = snapshot(
            root: "/Users/mia/Developer/Colofa",
            gitDirectory: "/Users/mia/Git/Colofa.git"
        )
        #expect(repository.hasSeparateGitDirectory)
    }

    /// A submodule's Git directory lives in the superproject's `.git/modules`, which shares the
    /// root's own prefix without being the root's `.git`.
    @Test
    func submoduleShowsItsGitDirectory() {
        let repository = snapshot(
            root: "/Users/mia/Developer/App/Vendor/Colofa",
            gitDirectory: "/Users/mia/Developer/App/.git/modules/Vendor/Colofa"
        )
        #expect(repository.hasSeparateGitDirectory)
    }

    /// The trailing slash a directory URL carries must not read as a different location, or an
    /// ordinary Repository would show a row repeating the path above it.
    @Test
    func trailingSlashDoesNotCountAsSeparate() {
        let root = URL(filePath: "/Users/mia/Developer/Colofa", directoryHint: .isDirectory)
        let repository = RepositorySnapshot(
            name: "Colofa",
            rootURL: root,
            gitDirectoryURL: root.appending(path: ".git", directoryHint: .isDirectory),
            head: .branch("main")
        )
        #expect(!repository.hasSeparateGitDirectory)
    }
}
