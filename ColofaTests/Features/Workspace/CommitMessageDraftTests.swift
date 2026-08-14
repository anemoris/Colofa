////
//  CommitMessageDraftTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Testing
@testable import Colofa

/// The message the composer hands to Git, and what entering or leaving Amend does to it.
struct CommitMessageDraftTests {
    @Test
    func aSummaryOnlyMessageCarriesNoTrailingStructure() {
        var draft = CommitMessageDraft()
        draft.summary = "  Add the composer  "
        draft.body = "   \n  "

        #expect(draft.message == "Add the composer")
        #expect(draft.hasSummary)
    }

    @Test
    func aDescriptionIsSeparatedFromTheSummaryByABlankLine() {
        var draft = CommitMessageDraft()
        draft.summary = "Add the composer"
        draft.body = "\nWhy it exists.\nAnd a second line.\n"

        #expect(draft.message == "Add the composer\n\nWhy it exists.\nAnd a second line.\n")
    }

    @Test
    func whitespaceAloneDoesNotCountAsASummary() {
        var draft = CommitMessageDraft()
        draft.summary = " \n\t "

        #expect(!draft.hasSummary)
        #expect(draft.message.isEmpty)
    }

    @Test
    func summaryLengthGuidanceCountsCharactersRatherThanBytes() {
        var draft = CommitMessageDraft()
        draft.summary = String(repeating: "提", count: CommitMessageDraft.recommendedSummaryLength)

        #expect(!draft.exceedsRecommendedSummaryLength)

        draft.summary += "交"

        #expect(draft.exceedsRecommendedSummaryLength)
    }

    @Test
    func enteringAmendPrefillsHeadsSummaryAndDescription() {
        var draft = CommitMessageDraft()
        draft.beginAmending(
            with: RepositoryHeadCommit(
                objectID: "fixture-head",
                summary: "Previous summary",
                body: "Previous body"
            )
        )

        #expect(draft.isAmending)
        #expect(draft.summary == "Previous summary")
        #expect(draft.body == "Previous body")
        #expect(draft.message == "Previous summary\n\nPrevious body\n")
    }

    @Test
    func leavingAmendGivesTheUsersOwnMessageBack() {
        var draft = CommitMessageDraft()
        draft.summary = "Work in progress"
        draft.body = "Own notes"
        draft.beginAmending(
            with: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous summary")
        )
        draft.summary = "Edited while amending"

        draft.endAmending()

        #expect(!draft.isAmending)
        #expect(draft.summary == "Work in progress")
        #expect(draft.body == "Own notes")
    }

    @Test
    func enteringAmendTwiceDoesNotOverwriteTheReplacedMessage() {
        var draft = CommitMessageDraft()
        draft.summary = "Work in progress"
        draft.beginAmending(with: RepositoryHeadCommit(objectID: "first", summary: "First"))
        draft.beginAmending(with: RepositoryHeadCommit(objectID: "second", summary: "Second"))

        #expect(draft.summary == "First")

        draft.endAmending()

        #expect(draft.summary == "Work in progress")
    }

    @Test
    func clearingLeavesNothingBehindForTheNextCommit() {
        var draft = CommitMessageDraft()
        draft.summary = "Own summary"
        draft.beginAmending(
            with: RepositoryHeadCommit(objectID: "fixture-head", summary: "Previous summary")
        )

        draft.clear()

        #expect(draft == CommitMessageDraft())
        #expect(!draft.isAmending)

        draft.endAmending()

        #expect(draft.summary.isEmpty)
    }
}
