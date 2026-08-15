////
//  GitDiffCommandTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct GitDiffCommandTests {
    @Test
    func comparesStagedContentAgainstHEAD() {
        let command = GitDiffCommand.patch(for: .index(paths: ["new.txt", "old.txt"]))

        #expect(command.arguments == [
            "--no-optional-locks", "-c", "core.quotePath=false", "--literal-pathspecs",
            "diff", "--cached", "--patch", "--find-renames",
            "--no-color", "--no-ext-diff", "--no-textconv", "--submodule=short",
            "--src-prefix=a/", "--dst-prefix=b/",
            "--", "new.txt", "old.txt",
        ])
        #expect(command.successfulExitStatuses == [0])
    }

    /// Anything a Repository or a user could otherwise decide about the shape of the output is
    /// stated by the command, because Colofa is the one parsing it.
    @Test
    func statesEveryFormatItParsesRatherThanInheritingIt() {
        let sources: [DiffSource] = [
            .index(paths: ["vendor"]),
            .workingTree(paths: ["vendor"]),
            .untracked(path: "vendor"),
        ]

        for source in sources {
            let arguments = GitDiffCommand.patch(for: source).arguments
            // `diff.submodule=log` would replace the two Commit IDs with a prose summary.
            #expect(arguments.contains("--submodule=short"))
            // `diff.noPrefix` and `diff.mnemonicPrefix` would leave the header naming two paths
            // with no way to tell where one ends.
            #expect(arguments.contains("--src-prefix=a/"))
            #expect(arguments.contains("--dst-prefix=b/"))
        }
    }

    @Test
    func comparesWorkingTreeContentAgainstTheIndex() {
        let command = GitDiffCommand.patch(for: .workingTree(paths: ["notes.txt"]))

        #expect(!command.arguments.contains("--cached"))
        #expect(command.arguments.suffix(2) == ["--", "notes.txt"])
        #expect(command.arguments.contains("--find-renames"))
    }

    @Test
    func comparesAnUntrackedPathAgainstNothingAndAcceptsTheDifferenceStatus() {
        let command = GitDiffCommand.patch(for: .untracked(path: "notes.txt"))

        #expect(command.arguments == [
            "--no-optional-locks", "-c", "core.quotePath=false",
            "diff", "--no-index", "--patch",
            "--no-color", "--no-ext-diff", "--no-textconv", "--submodule=short",
            "--src-prefix=a/", "--dst-prefix=b/",
            "--", "/dev/null", "notes.txt",
        ])
        // `--no-index` reports "the inputs differ" as status 1, which is the expected answer.
        #expect(command.successfulExitStatuses == [0, 1])
        // Rename detection is meaningless between two named files.
        #expect(!command.arguments.contains("--find-renames"))
        // `--literal-pathspecs` has nothing to govern where the arguments are filenames.
        #expect(!command.arguments.contains("--literal-pathspecs"))
    }

    @Test
    func countsChangedLinesWithoutWritingThePatchOut() {
        let command = GitDiffCommand.numstat(for: .index(paths: ["a.txt"]))

        #expect(command.arguments.contains("--numstat"))
        #expect(command.arguments.contains("-z"))
        #expect(!command.arguments.contains("--patch"))
    }

    @Test
    func namesThePathAChangeIsAbout() {
        #expect(DiffSource.index(paths: ["new.txt", "old.txt"]).path == "new.txt")
        #expect(DiffSource.untracked(path: "notes.txt").path == "notes.txt")
        #expect(
            DiffSource(
                change: RepositoryChange(path: "notes.txt", kind: .untracked),
                isStaged: false
            ) == .untracked(path: "notes.txt")
        )
        #expect(
            DiffSource(
                change: RepositoryChange(path: "new.txt", kind: .renamed(from: "old.txt")),
                isStaged: true
            ) == .index(paths: ["new.txt", "old.txt"])
        )
        #expect(
            DiffSource(
                change: RepositoryChange(path: "a.txt", kind: .modified),
                isStaged: false
            ) == .workingTree(paths: ["a.txt"])
        )
    }
}
