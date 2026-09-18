////
//  StashIntegrationSupport.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// The Repository shape every Stash case starts from, and the readings each one asserts against.
enum StashIntegrationSupport {
    static let gitURL = URL(filePath: "/usr/bin/git")

    static let trackedPath = "tracked.txt"
    static let stagedPath = "staged.txt"
    static let untrackedPath = "untracked.txt"
    static let ignoredPath = "build/ignored.txt"

    static func backend(_ fixture: GitTestRepository) -> GitRepositoryService {
        GitRepositoryService(candidateURLs: [Self.gitURL], environment: fixture.environment)
    }

    /// A Repository holding one of each kind of work a Stash has to tell apart: a tracked file
    /// changed in the working tree, a tracked file changed in the index, an untracked file, and
    /// an ignored one.
    static func stashableRepository(_ fixture: GitTestRepository) throws -> URL {
        let repositoryURL = try fixture.createWorkingRepository()
        try writeFile("base\n", to: trackedPath, in: repositoryURL)
        try writeFile("base\n", to: stagedPath, in: repositoryURL)
        try writeFile("build/\n", to: ".gitignore", in: repositoryURL)
        try fixture.git(
            ["add", "--", trackedPath, stagedPath, ".gitignore"],
            in: repositoryURL
        )
        try fixture.git(["commit", "-m", "Add fixture files"], in: repositoryURL)

        try writeFile("working tree\n", to: trackedPath, in: repositoryURL)
        try writeFile("index\n", to: stagedPath, in: repositoryURL)
        try fixture.git(["add", "--", stagedPath], in: repositoryURL)
        try writeFile("untracked\n", to: untrackedPath, in: repositoryURL)
        try FileManager.default.createDirectory(
            at: repositoryURL.appending(path: "build", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try writeFile("ignored\n", to: ignoredPath, in: repositoryURL)
        return repositoryURL
    }

    /// Runs one Stash exactly the way the sheet does.
    static func createStash(
        _ fixture: GitTestRepository,
        in repositoryURL: URL,
        message: String = "",
        keepsStagedChanges: Bool = false,
        includesUntrackedFiles: Bool = false
    ) async throws {
        var draft = StashCreationDraft()
        draft.message = message
        draft.keepsStagedChanges = keepsStagedChanges
        draft.includesUntrackedFiles = includesUntrackedFiles
        try await backend(fixture).runMutation(draft.arguments, in: repositoryURL)
    }

    static func exists(_ path: String, in repositoryURL: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: repositoryURL.appending(path: path).normalizedFilePath
        )
    }

    static func contents(of path: String, in repositoryURL: URL) throws -> String {
        try String(contentsOf: repositoryURL.appending(path: path), encoding: .utf8)
    }

    /// The paths the Stash reports, in the order Colofa reports them.
    static func savedPaths(of detail: StashDetail) -> [String] {
        detail.files.map(\.summary.newPath)
    }
}
