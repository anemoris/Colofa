////
//  BranchCreationDraftTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Testing
@testable import Colofa

struct BranchCreationDraftTests {
    private static let startPoint = BranchStartPoint(
        origin: .commit,
        revision: "0123456789abcdef0123456789abcdef01234567",
        label: "0123456",
        summary: "Fixture commit"
    )

    /// Git accepts no whitespace in a branch name at all, so a pasted name with a trailing
    /// newline must not fail validation for a character the user cannot see.
    ///
    /// It is dropped from the name itself rather than only where the name is used, so the field
    /// shows the name that will be created rather than one the dialog quietly rewrites.
    @Test
    func dropsWhitespaceAroundTheNameItShows() {
        var draft = BranchCreationDraft(startPoint: Self.startPoint)
        draft.name = "  feature/work\n"

        #expect(draft.name == "feature/work")
        #expect(
            draft.arguments == ["switch", "--create", "feature/work", Self.startPoint.revision]
        )
    }

    /// Whitespace is all that is dropped: a name Git refuses for any other reason reaches Git
    /// exactly as typed, so Git is the one that refuses it.
    @Test
    func changesNothingElseAboutTheName() {
        var draft = BranchCreationDraft(startPoint: Self.startPoint)
        draft.name = " bad name "

        #expect(draft.name == "bad name")
    }

    /// An answer belongs to the name it was given about, and normalizing on the way in is what
    /// keeps the two comparable.
    @Test
    func keepsGitsAnswerAttachedToTheNormalizedName() {
        var draft = BranchCreationDraft(startPoint: Self.startPoint)
        draft.name = "  feature  "
        draft.recordFormatCheck(of: "feature", isValid: true)

        #expect(draft.formatValidity == true)

        draft.name = "feature/other"
        #expect(draft.formatValidity == nil)
    }

    /// Creating without Checkout writes one ref: nothing here moves HEAD or the working tree.
    @Test
    func createsWithoutCheckoutThroughGitBranch() {
        var draft = BranchCreationDraft(startPoint: Self.startPoint)
        draft.name = "feature"
        draft.checksOutNewBranch = false

        #expect(draft.arguments == ["branch", "--", "feature", Self.startPoint.revision])
    }

    /// One command creates and switches, so a Checkout Git refuses leaves no branch behind.
    @Test
    func createsAndChecksOutThroughOneCommand() {
        var draft = BranchCreationDraft(startPoint: Self.startPoint)
        draft.name = "feature"

        #expect(draft.checksOutNewBranch)
        #expect(draft.arguments == ["switch", "--create", "feature", Self.startPoint.revision])
    }

    /// Neither form may reach for a force, a merge, or a Stash.
    @Test
    func neverOffersAwayToOverwriteLocalWork() {
        var draft = BranchCreationDraft(startPoint: Self.startPoint)
        draft.name = "feature"
        let refused = ["--force", "-f", "--force-create", "-C", "--merge", "-m", "stash"]

        for checksOut in [true, false] {
            draft.checksOutNewBranch = checksOut
            #expect(!draft.arguments.contains(where: refused.contains))
        }
    }

    @Test
    func answersAboutTheNameCurrentlyTyped() {
        var draft = BranchCreationDraft(startPoint: Self.startPoint)
        draft.name = "feature"
        draft.recordFormatCheck(of: "feature", isValid: true)
        #expect(draft.formatValidity == true)

        draft.name = "feature+"
        #expect(draft.formatValidity == nil)
    }

    /// A refusal describes the name that caused it, so editing that name retires it.
    @Test
    func dropsTheLastRefusalWhenTheNameChanges() {
        var draft = BranchCreationDraft(startPoint: Self.startPoint)
        draft.name = "feature"
        draft.recordFailure(
            .commandFailed(GitFailureDetails(command: "git branch", output: "refused"))
        )
        #expect(draft.failure != nil)

        draft.name = "feature-2"
        #expect(draft.failure == nil)
    }
}
