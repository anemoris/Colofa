////
//  PullCommandTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a Pull hands Git, which is the whole of Colofa's integration policy: fast-forward or
/// nothing.
struct PullCommandTests {
    /// Options no Pull may ever carry. Each one would either choose an integration method on the
    /// user's behalf or touch work the user never offered up.
    private nonisolated static let refusedOptions = [
        "--rebase", "-r", "--no-ff", "--ff", "--autostash", "--squash", "--force", "-f",
        "--commit", "--strategy", "-s", "--allow-unrelated-histories", "--update-head-ok",
    ]

    @Test
    func fetchesTheCurrentBranchesOwnRemoteWithoutNamingIt() {
        #expect(PullCommand.fetch == ["fetch"])
    }

    /// `git pull` is deliberately not the command: it decides between merging and rebasing from
    /// configuration, which is the decision Colofa refuses to make for the user.
    @Test
    func neverRunsGitPull() {
        #expect(!PullCommand.fetch.contains("pull"))
        #expect(!PullCommand.fastForward.contains("pull"))
    }

    @Test
    func advancesOnlyByFastForward() {
        #expect(PullCommand.fastForward.first == "merge")
        #expect(PullCommand.fastForward.contains("--ff-only"))
    }

    /// `merge.autoStash` would otherwise stash the working tree, fast-forward, and re-apply —
    /// which can end in a conflicted tree nobody asked for.
    @Test
    func refusesToStashTheWorkingTreeOnTheUsersBehalf() {
        #expect(PullCommand.fastForward.contains("--no-autostash"))
    }

    @Test
    func movesToGitsOwnNameForTheUpstream() {
        #expect(PullCommand.fastForward.last == "@{upstream}")
        #expect(PullCommand.upstreamRevision == "@{upstream}")
    }

    /// The revision travels after `--`, so a Ref shaped like an option never reaches Git's
    /// option parser.
    @Test
    func keepsTheRevisionOutOfGitsOptionParser() throws {
        let separator = try #require(PullCommand.fastForward.firstIndex(of: "--"))
        #expect(PullCommand.fastForward.index(after: separator) == PullCommand.fastForward.count - 1)
    }

    @Test(arguments: PullCommandTests.refusedOptions)
    func carriesNoOptionThatWouldChooseAnIntegrationMethod(_ option: String) {
        #expect(!PullCommand.fetch.contains(option))
        #expect(!PullCommand.fastForward.contains(option))
    }
}
