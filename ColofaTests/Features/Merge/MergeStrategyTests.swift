////
//  MergeStrategyTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// The three commands a Merge can be, read without going through the Store.
struct MergeStrategyTests {
    private let source = MergeSource(
        name: "feature",
        revision: "refs/heads/feature",
        isRemote: false
    )

    @Test
    func theDialogOpensOnGitsOwnBehaviour() {
        #expect(MergeStrategy.preselected == .automatic)
    }

    @Test
    func theThreeChoicesAreOfferedInPolicyOrder() {
        #expect(
            MergeStrategy.allCases == [.automatic, .fastForwardOnly, .alwaysCreateMergeCommit]
        )
    }

    /// Each policy is spelled out rather than left to `merge.ff`, which would otherwise turn one
    /// choice into another without the user asking.
    @Test(
        arguments: [
            (MergeStrategy.automatic, "--ff"),
            (MergeStrategy.fastForwardOnly, "--ff-only"),
            (MergeStrategy.alwaysCreateMergeCommit, "--no-ff"),
        ]
    )
    func eachStrategyNamesItsOwnPolicy(strategy: MergeStrategy, option: String) {
        let arguments = strategy.arguments(merging: source)

        #expect(arguments.first == "merge")
        #expect(arguments.contains(option))
        // Exactly one policy travels with the command, so nothing later in the list can overrule
        // what the user chose.
        #expect(arguments.filter { ["--ff", "--ff-only", "--no-ff"].contains($0) } == [option])
    }

    /// `merge.autoStash` is configuration Colofa would otherwise inherit, and it would stash the
    /// working tree, merge, and re-apply — a Stash nobody asked for.
    @Test(arguments: MergeStrategy.allCases)
    func everyStrategyRefusesToStashOnTheUsersBehalf(strategy: MergeStrategy) {
        #expect(strategy.arguments(merging: source).contains("--no-autostash"))
    }

    /// A button press must not launch the user's configured editor.
    @Test(arguments: MergeStrategy.allCases)
    func everyStrategyTakesThePreparedMessageWithoutAnEditor(strategy: MergeStrategy) {
        #expect(strategy.arguments(merging: source).contains("--no-edit"))
    }

    @Test(arguments: MergeStrategy.allCases)
    func noStrategyCarriesAnOptionColofaRefusesToOffer(strategy: MergeStrategy) {
        let arguments = strategy.arguments(merging: source)
        for option in refusedMergeOptions {
            #expect(!arguments.contains(option), "\(option) reached a Merge command")
        }
    }

    /// The revision is spelled in full and kept out of Git's option parser, so a tag sharing the
    /// Branch's name can never be what gets merged.
    @Test(arguments: MergeStrategy.allCases)
    func everyStrategyMergesTheFullRefnameAfterTheSeparator(strategy: MergeStrategy) throws {
        let arguments = strategy.arguments(merging: source)
        let separator = try #require(arguments.firstIndex(of: "--"))

        #expect(Array(arguments[arguments.index(after: separator)...]) == ["refs/heads/feature"])
    }

    /// Git would otherwise record the full refname it was handed, leaving
    /// `Merge branch 'refs/heads/feature'` in History forever.
    @Test
    func theMergeCommitCarriesTheNameTheUserChose() throws {
        let arguments = MergeStrategy.automatic.arguments(merging: source)
        let messageIndex = try #require(arguments.firstIndex(of: "-m"))

        #expect(arguments[arguments.index(after: messageIndex)] == "Merge branch 'feature'")
    }
}
