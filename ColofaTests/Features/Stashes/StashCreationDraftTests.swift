////
//  StashCreationDraftTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// The command one Stash sheet becomes, read without going through the Store.
struct StashCreationDraftTests {
    @Test
    func bothOptionsStartOff() {
        let draft = StashCreationDraft()

        #expect(!draft.keepsStagedChanges)
        #expect(!draft.includesUntrackedFiles)
        #expect(draft.message.isEmpty)
        #expect(draft.failure == nil)
    }

    /// Every combination of the two options, and exactly the flag each one adds.
    @Test(
        arguments: [
            (false, false, ["stash", "push"]),
            (true, false, ["stash", "push", "--keep-index"]),
            (false, true, ["stash", "push", "--include-untracked"]),
            (true, true, ["stash", "push", "--keep-index", "--include-untracked"]),
        ]
    )
    func eachOptionCombinationNamesItsOwnFlags(
        keepsStagedChanges: Bool,
        includesUntrackedFiles: Bool,
        expected: [String]
    ) {
        var draft = StashCreationDraft()
        draft.keepsStagedChanges = keepsStagedChanges
        draft.includesUntrackedFiles = includesUntrackedFiles

        #expect(draft.arguments == expected)
    }

    /// `--all` sweeps in ignored files, which are build output and secrets rather than work.
    @Test(
        arguments: [
            (false, false), (true, false), (false, true), (true, true),
        ]
    )
    func noCombinationEverStashesIgnoredFiles(
        keepsStagedChanges: Bool,
        includesUntrackedFiles: Bool
    ) {
        var draft = StashCreationDraft()
        draft.keepsStagedChanges = keepsStagedChanges
        draft.includesUntrackedFiles = includesUntrackedFiles

        #expect(!draft.arguments.contains("--all"))
        #expect(!draft.arguments.contains("-a"))
    }

    @Test
    func aMessageTravelsAsItsOwnArgument() {
        var draft = StashCreationDraft()
        draft.message = "parser rewrite"

        #expect(draft.arguments == ["stash", "push", "-m", "parser rewrite"])
    }

    /// Surrounding whitespace is not a message, so it does not become one.
    @Test(arguments: ["", "   ", "\n\t "])
    func aBlankMessageIsNoMessageAtAll(message: String) {
        var draft = StashCreationDraft()
        draft.message = message

        #expect(draft.arguments == ["stash", "push"])
        #expect(draft.trimmedMessage.isEmpty)
    }

    @Test
    func aMessageIsTrimmedRatherThanPassedWithItsWhitespace() {
        var draft = StashCreationDraft()
        draft.message = "  parser rewrite\n"

        #expect(draft.arguments == ["stash", "push", "-m", "parser rewrite"])
    }

    /// A message and both options together, in the order Git reads them.
    @Test
    func everyChoiceTravelsWithTheSameCommand() {
        var draft = StashCreationDraft()
        draft.message = "everything"
        draft.keepsStagedChanges = true
        draft.includesUntrackedFiles = true

        #expect(
            draft.arguments == [
                "stash", "push", "--keep-index", "--include-untracked", "-m", "everything",
            ]
        )
    }

    @Test
    func aRefusalIsHeldUntilItIsCleared() {
        var draft = StashCreationDraft()
        let details = GitFailureDetails(command: "git stash push", output: "refused")

        draft.recordFailure(details)
        #expect(draft.failure == details)

        draft.clearFailure()
        #expect(draft.failure == nil)
    }
}
