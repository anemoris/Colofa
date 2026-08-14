////
//  WorkspaceStateAmendDraftTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// How an Amend draft holds up against the Commit it rewrites: what a reload does to it, and
/// what it says about a message the composer cannot reproduce.
@Suite(.serialized)
final class WorkspaceStateAmendDraftTests {
    private let defaults: UserDefaults
    private let repositoryURL = URL(filePath: "/tmp/Amend Draft Store")

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateAmendDraftTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    @MainActor
    func refreshCancelsAmendWhenHeadChangedExternally() async throws {
        let original = RepositoryHeadCommit(
            objectID: "original",
            summary: "Original summary",
            isPublished: true
        )
        let replacement = RepositoryHeadCommit(
            objectID: "replacement",
            summary: "Replacement summary",
            isPublished: true
        )
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(at: repositoryURL, headCommit: original),
                    committableRepository(at: repositoryURL, headCommit: replacement),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.commitDraft.summary = "Own draft"
        state.setAmending(true)
        state.commitDraft.summary = "Discarded Amend edit"

        await state.refresh()

        #expect(!state.commitDraft.isAmending)
        #expect(state.commitDraft.summary == "Own draft")
        #expect(!state.isConfirmingHistoryRewrite)
        #expect(state.isShowingStaleAmendAlert)
        #expect(await stub.recordedMutations().isEmpty)
    }

    /// A successful Amend moves HEAD on purpose, so the reload that reports it must not be read
    /// as somebody else rewriting History underneath the composer.
    @Test
    @MainActor
    func aSuccessfulAmendIsNotReportedAsAnExternalHeadChange() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "before",
                            summary: "Before summary"
                        ),
                        stagedChanges: []
                    ),
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "after",
                            summary: "After summary"
                        ),
                        stagedChanges: []
                    ),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        state.setAmending(true)
        state.commitDraft.summary = "After summary"
        await state.commit()

        #expect(await stub.recordedArguments() == [["commit", "--amend", "--file=-"]])
        #expect(!state.isShowingStaleAmendAlert)
        #expect(!state.commitDraft.isAmending)
        #expect(state.commitDraft == CommitMessageDraft())
    }

    /// A scene activation refreshes unconditionally, so an ordinary reload can land in the middle
    /// of an Amend and see the HEAD that Amend just moved. It is still Colofa's own rewrite.
    @Test
    @MainActor
    func aRefreshLandingDuringAnAmendIsNotReportedAsAnExternalHeadChange() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "before",
                            summary: "Before summary"
                        ),
                        stagedChanges: []
                    ),
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "after",
                            summary: "After summary"
                        ),
                        stagedChanges: []
                    ),
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "after",
                            summary: "After summary"
                        ),
                        stagedChanges: []
                    ),
                ],
            ],
            mutationDelay: .milliseconds(50)
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        state.setAmending(true)
        state.commitDraft.summary = "After summary"

        // The scene refresh races the Amend exactly as a window activation would.
        async let amend: Void = state.commit()
        async let sceneRefresh: Void = state.refresh()
        _ = await (amend, sceneRefresh)

        #expect(await stub.recordedArguments() == [["commit", "--amend", "--file=-"]])
        #expect(!state.isShowingStaleAmendAlert)
        #expect(state.commitDraft == CommitMessageDraft())
    }

    /// The exemption covers the Amend's own reload and nothing else: a HEAD that moved while
    /// Colofa was staging is still somebody else's rewrite.
    @Test
    @MainActor
    func anUnrelatedMutationStillReportsAHeadChangedUnderneathAnAmend() async throws {
        let unstaged = RepositoryChange(path: "notes.txt", kind: .untracked)
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "before",
                            summary: "Before summary"
                        ),
                        unstagedChanges: [unstaged]
                    ),
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "rewritten elsewhere",
                            summary: "Rewritten elsewhere"
                        )
                    ),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.commitDraft.summary = "Own draft"
        state.setAmending(true)

        await state.stage(unstaged)

        #expect(
            await stub.recordedArguments() == [
                ["--literal-pathspecs", "add", "--", "notes.txt"],
            ]
        )
        #expect(state.isShowingStaleAmendAlert)
        #expect(!state.commitDraft.isAmending)
        #expect(state.commitDraft.summary == "Own draft")
    }

    /// A Commit that failed rewrote nothing Colofa asked for, so a Hook that moved HEAD before
    /// refusing still has to invalidate the draft.
    @Test
    @MainActor
    func aFailedAmendStillReportsAHeadThatMovedUnderneathIt() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "before",
                            summary: "Before summary"
                        )
                    ),
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "moved by a hook",
                            summary: "Moved by a hook"
                        )
                    ),
                ],
            ],
            mutationError: .commandFailed(
                GitFailureDetails(command: "\"git\" \"commit\"", output: "refused")
            )
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.setAmending(true)

        await state.commit()

        #expect(state.isShowingStaleAmendAlert)
        #expect(!state.commitDraft.isAmending)
    }

    @Test
    @MainActor
    func amendingAMessageTheComposerCannotReproduceIsAnnounced() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "reformatted",
                            summary: "line one",
                            body: "line two",
                            amendReformatsMessage: true
                        )
                    ),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        #expect(!state.amendReformatsMessage)

        state.setAmending(true)

        #expect(state.amendReformatsMessage)

        state.setAmending(false)

        #expect(!state.amendReformatsMessage)
    }
}
