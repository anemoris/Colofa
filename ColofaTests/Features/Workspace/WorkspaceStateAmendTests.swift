////
//  WorkspaceStateAmendTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Amend: prefilling HEAD's message, both amend forms, and the
/// confirmation that guards published history.
@Suite(.serialized)
final class WorkspaceStateAmendTests {
    private let defaults: UserDefaults
    private let repositoryURL = URL(filePath: "/tmp/Amend Store")

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateAmendTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    @MainActor
    func amendingPrefillsHeadAndRewritesTheMessageOnACleanIndex() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "previous",
                            summary: "Previous summary",
                            body: "Previous body"
                        ),
                        stagedChanges: []
                    ),
                    committableRepository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "corrected",
                            summary: "Corrected summary"
                        ),
                        stagedChanges: []
                    ),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        state.setAmending(true)

        #expect(state.commitDraft.isAmending)
        #expect(state.commitDraft.summary == "Previous summary")
        #expect(state.commitDraft.body == "Previous body")

        state.commitDraft.summary = "Corrected summary"
        state.commitDraft.body = ""
        await state.commit()

        #expect(await stub.recordedMutations() == [
            RepositoryServiceStub.RecordedMutation(
                arguments: ["commit", "--amend", "--file=-"],
                standardInput: "Corrected summary"
            ),
        ])
        #expect(!state.commitDraft.isAmending)
    }

    @Test
    @MainActor
    func amendingWithStagedChangesUsesTheSameAmendCommand() async throws {
        let staged = RepositoryChange(path: "staged.txt", kind: .modified)
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(at: repositoryURL, stagedChanges: [staged]),
                    committableRepository(at: repositoryURL, stagedChanges: []),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        state.setAmending(true)
        await state.commit()

        #expect(await stub.recordedArguments() == [["commit", "--amend", "--file=-"]])
        #expect(state.repository?.stagedChanges.isEmpty == true)
    }

    @Test
    @MainActor
    func amendingPublishedHistoryRunsOnlyAfterAnExplicitConfirmation() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    publishedRepository(),
                    committableRepository(at: repositoryURL),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        state.setAmending(true)
        #expect(state.isAmendingPublishedCommit)
        await state.commit()

        #expect(state.isConfirmingHistoryRewrite)
        #expect(await stub.recordedMutations().isEmpty)

        state.cancelHistoryRewrite()

        #expect(!state.isConfirmingHistoryRewrite)
        #expect(await stub.recordedMutations().isEmpty)

        await state.commit()
        await state.confirmHistoryRewrite()

        #expect(await stub.recordedArguments() == [["commit", "--amend", "--file=-"]])
        #expect(!state.isConfirmingHistoryRewrite)
    }

    @Test
    @MainActor
    func amendingUnpublishedHistoryNeedsNoConfirmation() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(at: repositoryURL),
                    committableRepository(at: repositoryURL),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        state.setAmending(true)
        await state.commit()

        #expect(!state.isConfirmingHistoryRewrite)
        #expect(await stub.recordedArguments() == [["commit", "--amend", "--file=-"]])
    }

    @Test
    @MainActor
    func leavingAmendCancelsAPendingHistoryRewrite() async throws {
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [publishedRepository()]])
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        state.setAmending(true)
        await state.commit()
        #expect(state.isConfirmingHistoryRewrite)

        state.setAmending(false)
        // The dialog's confirming button can still arrive after SwiftUI dismissed it, and must
        // not rewrite anything once the Amend it warned about is gone.
        await state.confirmHistoryRewrite()

        #expect(!state.isConfirmingHistoryRewrite)
        #expect(await stub.recordedMutations().isEmpty)
    }

    @Test
    @MainActor
    func aFailedAmendIsReportedAsAnAmend() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(at: repositoryURL),
                    committableRepository(at: repositoryURL),
                ],
            ],
            mutationError: .commandFailed(
                GitFailureDetails(command: "\"git\" \"commit\"", output: "refused")
            )
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        state.setAmending(true)
        await state.commit()

        guard case .mutationAlert(_, let title) = state.repositoryFailure else {
            Issue.record("Expected the Amend failure alert")
            return
        }
        #expect(title == .amendCommitFailed)
        #expect(state.commitDraft.isAmending)
    }

    @Test
    @MainActor
    func amendIsUnavailableWithoutACommitToRewrite() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    repository(
                        at: repositoryURL,
                        head: .unbornBranch("main"),
                        stagedChanges: [RepositoryChange(path: "first.txt", kind: .added)],
                        configuration: identityConfiguration()
                    ),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)

        state.setAmending(true)

        #expect(!state.canAmend)
        #expect(!state.commitDraft.isAmending)
    }

    @Test
    @MainActor
    func amendIsUnavailableWhenHeadCannotBeRewrittenSafely() async throws {
        let operationURL = URL(filePath: "/tmp/Amend Operation")
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(
                        at: repositoryURL,
                        head: .detached("0123456789abcdef")
                    ),
                ],
                operationURL: [
                    committableRepository(at: operationURL, operation: .rebase),
                ],
            ]
        )

        let detached = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        let operation = await openedWorkspace(stub, at: operationURL, defaults: defaults)

        #expect(!detached.canAmend)
        #expect(!operation.canAmend)
    }

    private func publishedRepository() -> RepositorySnapshot {
        committableRepository(
            at: repositoryURL,
            headCommit: RepositoryHeadCommit(
                objectID: "published",
                summary: "Published summary",
                isPublished: true
            )
        )
    }
}
