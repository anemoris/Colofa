////
//  AmendIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
struct AmendIntegrationTests {
    @Test
    @MainActor
    func amendWithoutStagedChangesRewritesOnlyTheMessage() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        let originalTree = try fixture.git(["rev-parse", "HEAD^{tree}"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.setAmending(true)

        #expect(state.commitDraft.summary == "Fixture commit")

        state.commitDraft.summary = "Corrected summary"
        state.commitDraft.body = "Corrected body."
        await state.commit()

        #expect(try fixture.git(["rev-parse", "HEAD^{tree}"], in: repositoryURL) == originalTree)
        #expect(try fixture.git(["rev-list", "--count", "HEAD"], in: repositoryURL) == "1")
        #expect(
            try fixture.git(["log", "--max-count=1", "--format=%B"], in: repositoryURL)
                == "Corrected summary\n\nCorrected body."
        )
        #expect(state.repository?.headCommit?.summary == "Corrected summary")
        #expect(!state.commitDraft.isAmending)
        #expect(!state.isShowingStaleAmendAlert)
    }

    @Test
    @MainActor
    func amendWithStagedChangesIncludesExactlyThoseChanges() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try fixture.createCommit(in: repositoryURL)
        try Data("added\n".utf8).write(to: repositoryURL.appending(path: "added.txt"))
        _ = try fixture.git(["add", "--", "added.txt"], in: repositoryURL)
        try Data("left out\n".utf8).write(to: repositoryURL.appending(path: "left-out.txt"))

        let state = await openedWorkspace(fixture, at: repositoryURL)
        state.setAmending(true)
        await state.commit()

        #expect(try fixture.git(["rev-list", "--count", "HEAD"], in: repositoryURL) == "1")
        #expect(
            try fixture.git(["show", "--name-only", "--format=", "HEAD"], in: repositoryURL)
                == "README.md\nadded.txt"
        )
        #expect(state.repository?.unstagedChanges.map(\.path) == ["left-out.txt"])
    }

    /// Git's `%s` joins every line before the first blank one with spaces, so reading HEAD that
    /// way would hand Amend a Summary the Commit never held.
    @Test
    @MainActor
    func aMultiLineSubjectIsReadVerbatimAndFlaggedAsUnreproducible() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("first\n".utf8).write(to: repositoryURL.appending(path: "first.txt"))
        _ = try fixture.git(["add", "--", "first.txt"], in: repositoryURL)
        _ = try fixture.git(
            ["commit", "-m", "line one\nline two\n\nreal body"],
            in: repositoryURL
        )

        let state = await openedWorkspace(fixture, at: repositoryURL)
        let headCommit = try #require(state.repository?.headCommit)

        #expect(headCommit.summary == "line one")
        #expect(headCommit.body == "line two\n\nreal body")
        #expect(headCommit.amendReformatsMessage)

        state.setAmending(true)
        #expect(state.amendReformatsMessage)
        #expect(state.commitDraft.summary == "line one")
    }

    /// Git's default `whitespace` cleanup keeps leading spaces, so this message really is stored
    /// as `"  Leading spaces\n"` and an Amend really would drop them.
    @Test
    @MainActor
    func leadingWhitespaceTheComposerWouldDropIsFlagged() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("first\n".utf8).write(to: repositoryURL.appending(path: "first.txt"))
        _ = try fixture.git(["add", "--", "first.txt"], in: repositoryURL)
        _ = try fixture.git(["commit", "-m", "  Leading spaces"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        let headCommit = try #require(state.repository?.headCommit)

        #expect(headCommit.summary == "Leading spaces")
        #expect(headCommit.amendReformatsMessage)
    }

    /// The one check that cannot be tautological: real Git decides, for every message shape the
    /// reader claims to understand, whether an Amend that changes nothing leaves the message
    /// alone. `amendReformatsMessage` has to agree with what actually happened.
    ///
    /// `--cleanup=verbatim` is how the awkward shapes get stored at all — Git's default cleanup
    /// would have normalized them on the way in.
    @Test(arguments: [
        "Summary",
        "Summary\n\nBody",
        "Summary\n\nFirst paragraph.\n\nSecond paragraph.",
        "line one\nline two\n\nreal body",
        "Summary\n\n    indented",
        "  Leading spaces",
        "Summary   \n\nBody",
        "Summary\n\nBody\n\n",
        "Summary\n\nFirst line   \nSecond",
        "Summary\n\nFirst\n\n\nSecond",
    ])
    @MainActor
    func amendReformatsMessageAgreesWithWhatGitStores(message: String) async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("first\n".utf8).write(to: repositoryURL.appending(path: "first.txt"))
        _ = try fixture.git(["add", "--", "first.txt"], in: repositoryURL)
        _ = try fixture.git(["commit", "--cleanup=verbatim", "-m", message], in: repositoryURL)
        let original = try fixture.rawCommitMessage(in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        let predictsRewrite = try #require(state.repository?.headCommit).amendReformatsMessage

        state.setAmending(true)
        await state.commit()

        let amended = try fixture.rawCommitMessage(in: repositoryURL)
        #expect(
            (amended != original) == predictsRewrite,
            """
            Amending “\(message)” \(amended == original ? "kept" : "rewrote") the message, \
            but amendReformatsMessage said it would \(predictsRewrite ? "rewrite" : "keep") it
            """
        )
    }

    @Test
    @MainActor
    func anOrdinaryMessageRoundTripsThroughAmendUnchanged() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        try Data("first\n".utf8).write(to: repositoryURL.appending(path: "first.txt"))
        _ = try fixture.git(["add", "--", "first.txt"], in: repositoryURL)
        _ = try fixture.git(
            ["commit", "-m", "Summary\n\nFirst paragraph.\n\nSecond paragraph."],
            in: repositoryURL
        )
        let original = try fixture.git(
            ["log", "--max-count=1", "--format=%B"],
            in: repositoryURL
        )

        let state = await openedWorkspace(fixture, at: repositoryURL)
        #expect(state.repository?.headCommit?.amendReformatsMessage == false)

        state.setAmending(true)
        await state.commit()

        #expect(
            try fixture.git(["log", "--max-count=1", "--format=%B"], in: repositoryURL) == original
        )
        #expect(!state.isShowingStaleAmendAlert)
    }

    @Test
    @MainActor
    func headIsPublishedOnlyWhileARemoteRefContainsItAndAmendNeverPushes() async throws {
        let fixture = try GitTestRepository()
        let repositoryURL = try fixture.createWorkingRepository()
        let remoteURL = try fixture.createBareRemote()
        try fixture.createCommit(in: repositoryURL)
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        _ = try fixture.git(["push", "--set-upstream", "origin", "main"], in: repositoryURL)
        let publishedHead = try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)

        let state = await openedWorkspace(fixture, at: repositoryURL)
        #expect(state.repository?.headCommit?.isPublished == true)
        #expect(!state.isAmendingPublishedCommit)

        state.setAmending(true)
        #expect(state.isAmendingPublishedCommit)
        await state.commit()

        // The warning is pending, so nothing has run yet.
        #expect(state.isConfirmingHistoryRewrite)
        #expect(try fixture.git(["rev-parse", "HEAD"], in: repositoryURL) == publishedHead)

        state.commitDraft.summary = "Rewritten summary"
        await state.confirmHistoryRewrite()

        #expect(try fixture.git(["rev-parse", "HEAD"], in: repositoryURL) != publishedHead)
        #expect(state.repository?.headCommit?.isPublished == false)
        #expect(
            try fixture.git(["rev-parse", "main"], in: remoteURL) == publishedHead,
            "Commit and Amend must never push"
        )
    }
}
