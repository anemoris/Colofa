////
//  HistoryIntegrationSupport.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// Writes one file and commits it under its own name, so a fixture's History reads as the list of
/// paths it introduced.
func commitFile(
    _ name: String,
    in repositoryURL: URL,
    fixture: GitTestRepository
) throws {
    try writeFile("\(name)\n", to: name, in: repositoryURL)
    _ = try fixture.git(["add", "--", name], in: repositoryURL)
    _ = try fixture.git(["commit", "-m", name], in: repositoryURL)
}

func writeFile(_ contents: String, to path: String, in repositoryURL: URL) throws {
    try Data(contents.utf8).write(to: repositoryURL.appending(path: path))
}

/// A History long enough to cross the two-hundred Commit page boundary.
func createPagedHistory(
    in repositoryURL: URL,
    fixture: GitTestRepository,
    count: Int = 205
) throws {
    try fixture.createCommit(in: repositoryURL)
    for index in 1..<count {
        _ = try fixture.git(
            ["commit", "--allow-empty", "-m", "Commit \(index)"],
            in: repositoryURL
        )
    }
}
