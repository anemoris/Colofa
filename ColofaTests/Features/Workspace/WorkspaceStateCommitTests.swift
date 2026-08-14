////
//  WorkspaceStateCommitTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Store-level behaviour of Commit: the command it produces, what the message travels in, and
/// what happens to the composer afterwards. Amend has its own suite.
@Suite(.serialized)
final class WorkspaceStateCommitTests {
    private let defaults: UserDefaults
    private let repositoryURL = URL(filePath: "/tmp/Commit Store")

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateCommitTests"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    @MainActor
    func commitSendsOnlyTheMessageAndClearsTheComposer() async throws {
        let staged = RepositoryChange(path: "staged.txt", kind: .modified)
        let unstaged = RepositoryChange(path: "notes.txt", kind: .untracked)
        let committed = repository(
            at: repositoryURL,
            headCommit: RepositoryHeadCommit(objectID: "committed", summary: "Add the composer"),
            upstream: RepositoryUpstream(name: "origin/main", ahead: 1, behind: 0),
            unstagedChanges: [unstaged],
            totalCommitCount: 13,
            configuration: identityConfiguration()
        )
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(
                        at: repositoryURL,
                        upstream: RepositoryUpstream(name: "origin/main", ahead: 0, behind: 0),
                        stagedChanges: [staged],
                        unstagedChanges: [unstaged],
                        totalCommitCount: 12
                    ),
                    committed,
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.commitDraft.summary = "Add the composer"
        state.commitDraft.body = "Why it exists."

        #expect(state.canCommit)
        await state.commit()

        #expect(await stub.recordedMutations() == [
            RepositoryServiceStub.RecordedMutation(
                arguments: ["commit", "--file=-"],
                standardInput: "Add the composer\n\nWhy it exists.\n"
            ),
        ])
        #expect(state.commitDraft == CommitMessageDraft())
        #expect(state.repository == committed)
        #expect(state.repository?.totalCommitCount == 13)
        #expect(state.repository?.upstream?.ahead == 1)
        // Push stays a separate command: creating local history never contacts a remote.
        #expect(await stub.recordedArguments().allSatisfy { !$0.contains("push") })
    }

    @Test
    @MainActor
    func theFirstCommitOnAnUnbornBranchUsesTheSameCommand() async throws {
        let staged = RepositoryChange(path: "first.txt", kind: .added)
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    repository(
                        at: repositoryURL,
                        head: .unbornBranch("main"),
                        stagedChanges: [staged],
                        configuration: identityConfiguration()
                    ),
                    repository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "first",
                            summary: "First commit"
                        ),
                        configuration: identityConfiguration()
                    ),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.commitDraft.summary = "First commit"

        #expect(!state.canAmend)
        await state.commit()

        #expect(await stub.recordedArguments() == [["commit", "--file=-"]])
        #expect(state.repository?.headCommit?.summary == "First commit")
    }

    /// A failing hook or signing step leaves work the user still has to act on, so the message
    /// they wrote has to survive.
    @Test
    @MainActor
    func aFailedCommitKeepsTheComposerAndReportsTheSanitizedFailure() async throws {
        let failure = GitFailureDetails(
            command: "\"git\" \"commit\" \"--file=-\"",
            output: "<Repository>/.git/hooks/pre-commit refused the commit",
            exitStatus: 1
        )
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    committableRepository(at: repositoryURL),
                    committableRepository(at: repositoryURL),
                ],
            ],
            mutationError: .commandFailed(failure)
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.commitDraft.summary = "Add the composer"
        state.commitDraft.body = "Why it exists."

        await state.commit()

        #expect(state.commitDraft.summary == "Add the composer")
        #expect(state.commitDraft.body == "Why it exists.")
        guard case .mutationAlert(let error, let title) = state.repositoryFailure else {
            Issue.record("Expected the Commit failure alert")
            return
        }
        #expect(error == .commandFailed(failure))
        #expect(title == .commitFailed)
    }

    @Test
    @MainActor
    func anUnavailableCommitNeverRunsGit() async throws {
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    repository(
                        at: repositoryURL,
                        headCommit: RepositoryHeadCommit(
                            objectID: "previous",
                            summary: "Previous summary"
                        ),
                        configuration: identityConfiguration()
                    ),
                ],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.commitDraft.summary = "Nothing is staged"

        #expect(state.commitUnavailabilityReason == .noStagedChanges)
        await state.commit()

        #expect(await stub.recordedMutations().isEmpty)
    }

    @Test
    @MainActor
    func aMessageWrittenForOneRepositoryDoesNotFollowIntoAnother() async throws {
        let replacementURL = URL(filePath: "/tmp/Commit Store Replacement")
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [committableRepository(at: repositoryURL)],
                replacementURL: [repository(at: replacementURL)],
            ]
        )
        let state = await openedWorkspace(stub, at: repositoryURL, defaults: defaults)
        state.commitDraft.summary = "Belongs to the first Repository"
        state.setAmending(true)

        await state.handleRepositorySelection(.success(replacementURL))

        #expect(state.commitDraft == CommitMessageDraft())
    }
}
