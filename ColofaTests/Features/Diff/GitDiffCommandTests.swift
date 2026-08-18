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
            .commit(objectID: "aaaa", parentObjectID: "bbbb"),
            .commit(objectID: "aaaa", parentObjectID: nil),
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

    /// A Commit is compared against the parent it actually has, rather than by spelling `^`:
    /// a merge would otherwise be ambiguous and a root Commit would have nothing to name.
    @Test
    func comparesACommitAgainstItsParent() {
        let command = GitDiffCommand.patch(
            for: .commit(objectID: "aaaa", parentObjectID: "bbbb")
        )

        #expect(command.arguments == [
            "--no-optional-locks", "-c", "core.quotePath=false", "--literal-pathspecs",
            "diff", "--patch", "--find-renames",
            "--no-color", "--no-ext-diff", "--no-textconv", "--submodule=short",
            "--src-prefix=a/", "--dst-prefix=b/",
            "bbbb", "aaaa", "--",
        ])
        #expect(command.successfulExitStatuses == [0])
    }

    /// A Commit is read one file at a time, and a rename needs both of its paths in the pathspec
    /// or Git will not pair them.
    @Test
    func narrowsACommitToTheSelectedPaths() {
        let command = GitDiffCommand.patch(
            for: .commit(
                objectID: "aaaa",
                parentObjectID: "bbbb",
                paths: ["new.txt", "old.txt"]
            )
        )
        let root = GitDiffCommand.patch(
            for: .commit(objectID: "aaaa", parentObjectID: nil, paths: ["new.txt"])
        )

        #expect(command.arguments.suffix(5) == ["bbbb", "aaaa", "--", "new.txt", "old.txt"])
        #expect(root.arguments.suffix(3) == ["aaaa", "--", "new.txt"])
    }

    /// Nothing to compare against, so Git compares against an empty tree. `--root` is what makes
    /// it answer at all rather than printing nothing.
    @Test
    func comparesACommitWithNoParentAgainstAnEmptyTree() {
        let command = GitDiffCommand.numstat(for: .commit(objectID: "aaaa", parentObjectID: nil))

        #expect(command.arguments.contains("show"))
        #expect(command.arguments.contains("--root"))
        #expect(command.arguments.contains("--format="))
        #expect(command.arguments.contains("--numstat"))
        #expect(command.arguments.suffix(2) == ["aaaa", "--"])
        #expect(!command.arguments.contains("diff"))
    }

    /// The whole Commit is about every path it touched, so there is no single one to name; one
    /// file of it is about exactly that file.
    @Test
    func aCommitNamesAPathOnlyWhenItIsAboutOne() {
        #expect(DiffSource.commit(objectID: "aaaa", parentObjectID: nil).path == nil)
        #expect(
            DiffSource.commit(objectID: "aaaa", parentObjectID: nil, paths: ["a.txt"]).path
                == "a.txt"
        )
        #expect(DiffSource.workingTree(paths: ["a.txt"]).path == "a.txt")
        #expect(DiffSource.untracked(path: "a.txt").path == "a.txt")
    }
}
