////
//  MergeIntegrationSupport.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// The two Repository shapes every Merge case starts from, and the readings each one asserts
/// against, shared by the strategy suite and the Conflict-recovery suite.
enum MergeIntegrationSupport {
    static let gitURL = URL(filePath: "/usr/bin/git")

    static func backend(_ fixture: GitTestRepository) -> GitRepositoryService {
        GitRepositoryService(candidateURLs: [Self.gitURL], environment: fixture.environment)
    }

    /// One local Branch, spelled the way Colofa spells it: in full, so a tag of the same name can
    /// never be what gets merged.
    static func source(_ name: String) -> MergeSource {
        MergeSource(name: name, revision: "refs/heads/\(name)", isRemote: false)
    }

    /// `main` with `other` one Commit ahead of it, so a Merge of `other` can fast-forward.
    static func fastForwardableRepository(_ fixture: GitTestRepository) throws -> URL {
        let repositoryURL = try fixture.createWorkingRepository()
        try writeFile("base\n", to: "shared.txt", in: repositoryURL)
        try fixture.git(["add", "--", "shared.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Add shared"], in: repositoryURL)
        try fixture.git(["switch", "-c", "other"], in: repositoryURL)
        try writeFile("other\n", to: "shared.txt", in: repositoryURL)
        try writeFile("arriving\n", to: "arriving.txt", in: repositoryURL)
        try fixture.git(["add", "--", "shared.txt", "arriving.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Change shared"], in: repositoryURL)
        try fixture.git(["switch", "main"], in: repositoryURL)
        return repositoryURL
    }

    /// The same two branches with `main` moved on as well, so their histories have diverged and
    /// `shared.txt` conflicts.
    static func divergingRepository(_ fixture: GitTestRepository) throws -> URL {
        let repositoryURL = try fastForwardableRepository(fixture)
        try writeFile("main\n", to: "shared.txt", in: repositoryURL)
        try fixture.git(["add", "--", "shared.txt"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Change shared on main"], in: repositoryURL)
        return repositoryURL
    }

    /// Runs the Merge that stops at the Conflict, which is where every recovery case starts.
    static func startConflictedMerge(
        _ fixture: GitTestRepository,
        in repositoryURL: URL
    ) async throws {
        try? await backend(fixture).runMutation(
            MergeStrategy.automatic.arguments(merging: source("other")),
            in: repositoryURL
        )
    }

    static func contents(of path: String, in repositoryURL: URL) throws -> String {
        try String(contentsOf: repositoryURL.appending(path: path), encoding: .utf8)
    }

    /// How many parents HEAD has, which is what tells a fast-forward from a merge Commit.
    static func parentCount(in repositoryURL: URL, of fixture: GitTestRepository) throws -> Int {
        try fixture.git(["log", "--format=%P", "-1"], in: repositoryURL)
            .split(separator: " ")
            .count
    }
}
