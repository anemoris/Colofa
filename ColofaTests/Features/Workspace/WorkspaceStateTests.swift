////
//  WorkspaceStateTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

@Suite(.serialized)
final class WorkspaceStateTests {
    private let defaultsSuiteName: String
    private let defaults: UserDefaults

    init() throws {
        let suiteName = "com.anemoris.Colofa.WorkspaceStateTests"
        defaultsSuiteName = suiteName
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    @MainActor
    func baselineStartsInChangesWithoutARepository() {
        let state = WorkspaceState(
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )

        #expect(state.selectedSection == .changes)
        #expect(!state.isPresentingRepositoryPicker)
        #expect(!state.isShowingInspector)
    }

    @Test
    @MainActor
    func validSelectionBecomesTheCurrentRepository() async throws {
        defer { cleanupDefaults() }
        let repositoryURL = FileManager.default.temporaryDirectory
        let repository = repository(at: repositoryURL)
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [repository]]
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: []
        )

        await state.handleRepositorySelection(.success(repositoryURL))

        #expect(state.repository == repository)
        #expect(!state.isShowingRepositoryOpenError)
        #expect(
            defaults.string(forKey: "lastRepositoryPath")
                == repositoryURL.normalizedFilePath
        )
    }

    @Test
    @MainActor
    func loadedStatePreservesRealRefsOperationAndPartialStaging() async throws {
        let repositoryURL = URL(filePath: "/tmp/Real State")
        let partial = RepositoryChange(path: "partial.txt", kind: .modified)
        let repository = RepositorySnapshot(
            name: "Real State",
            rootURL: repositoryURL,
            gitDirectoryURL: repositoryURL.appending(path: ".git"),
            head: .branch("main"),
            upstream: RepositoryUpstream(name: "origin/main", ahead: 2, behind: 1),
            remotes: [RepositoryRemote(name: "origin", url: "remote")],
            localBranches: ["main", "topic"],
            remoteBranches: ["origin/main"],
            tags: ["v1"],
            stagedChanges: [
                RepositoryChange(path: "added.txt", kind: .added),
                partial,
                RepositoryChange(path: "renamed.txt", kind: .renamed(from: "old.txt")),
            ],
            unstagedChanges: [
                RepositoryChange(path: "conflict.txt", kind: .conflict),
                RepositoryChange(path: "deleted.txt", kind: .deleted),
                RepositoryChange(path: "link", kind: .typeChanged),
                partial,
                RepositoryChange(path: "untracked.txt", kind: .untracked),
            ],
            operation: .rebase,
            totalCommitCount: 12,
            gitObjectSize: 4_096
        )
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [repository]])
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )

        await state.handleRepositorySelection(.success(repositoryURL))

        #expect(state.repository == repository)
        #expect(state.repository?.changeCount == 7)
    }

    @Test
    @MainActor
    func refreshPublishesEveryActiveOperation() async throws {
        let repositoryURL = URL(filePath: "/tmp/Operations")
        let stub = RepositoryServiceStub(
            snapshots: [
                repositoryURL: [
                    repository(at: repositoryURL, operation: .merge),
                    repository(at: repositoryURL, operation: .rebase),
                    repository(at: repositoryURL, operation: .am),
                    repository(at: repositoryURL, operation: .cherryPick),
                    repository(at: repositoryURL, operation: .revert),
                ],
            ]
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )

        await state.handleRepositorySelection(.success(repositoryURL))
        #expect(state.repository?.operation == .merge)

        await state.refresh()
        #expect(state.repository?.operation == .rebase)

        await state.refresh()
        #expect(state.repository?.operation == .am)

        await state.refresh()
        #expect(state.repository?.operation == .cherryPick)

        await state.refresh()
        #expect(state.repository?.operation == .revert)
    }

    @Test
    @MainActor
    func failedRepositorySelectionIsVisibleToTheUser() async {
        let state = WorkspaceState(
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )

        await state.handleRepositorySelection(.failure(CocoaError(.fileReadNoSuchFile)))

        #expect(state.isShowingRepositoryOpenError)
    }

    @Test
    @MainActor
    func selectingAnotherValidRepositoryReplacesTheSession() async throws {
        let firstURL = URL(filePath: "/tmp/First")
        let secondURL = URL(filePath: "/tmp/Second")
        let first = repository(at: firstURL)
        let second = repository(at: secondURL, head: .unbornBranch("main"))
        let stub = RepositoryServiceStub(
            snapshots: [firstURL: [first], secondURL: [second]]
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )

        await state.handleRepositorySelection(.success(firstURL))
        await state.handleRepositorySelection(.success(secondURL))

        #expect(state.repository == second)
    }

    @Test
    @MainActor
    func lastValidRepositoryIsRestoredOnLaunch() async throws {
        defer { cleanupDefaults() }
        let repositoryURL = URL(
            filePath: "/tmp/My Repo 项目",
            directoryHint: .isDirectory
        )
        let expected = repository(at: repositoryURL, head: .detached("0123456789abcdef"))
        defaults.set(repositoryURL.normalizedFilePath, forKey: "lastRepositoryPath")
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [expected]])
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: []
        )

        await state.start()

        #expect(state.repository == expected)
        #expect(!state.isPresentingRepositoryPicker)
    }

    @Test
    @MainActor
    func invalidSavedRepositoryReturnsToThePicker() async throws {
        defer { cleanupDefaults() }
        let repositoryURL = URL(filePath: "/tmp/Missing")
        defaults.set(repositoryURL.normalizedFilePath, forKey: "lastRepositoryPath")
        let stub = RepositoryServiceStub(errors: [repositoryURL: .locationUnavailable])
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: []
        )

        await state.start()

        #expect(state.repository == nil)
        #expect(state.isPresentingRepositoryPicker)
        #expect(defaults.string(forKey: "lastRepositoryPath") == nil)
    }

    @Test
    @MainActor
    func unavailableGitPreventsAnUnusableWorkspace() async throws {
        let stub = RepositoryServiceStub(gitAvailability: .unavailable)
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: []
        )

        await state.start()

        #expect(state.gitAvailability == .unavailable)
        #expect(!state.isPresentingRepositoryPicker)
    }

    @Test
    @MainActor
    func supersededRefreshCannotReplaceANewerRepository() async throws {
        let firstURL = URL(filePath: "/tmp/Slow")
        let secondURL = URL(filePath: "/tmp/Fast")
        let first = repository(at: firstURL)
        let second = repository(at: secondURL, head: .branch("newer"))
        let stub = RepositoryServiceStub(
            snapshots: [firstURL: [first], secondURL: [second]],
            delays: [firstURL: .milliseconds(100)]
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )

        let slowOpen = Task {
            await state.handleRepositorySelection(.success(firstURL))
        }
        await Task.yield()
        await state.handleRepositorySelection(.success(secondURL))
        await slowOpen.value

        #expect(state.repository == second)
    }

    @Test
    @MainActor
    func activationRefreshCannotSupersedeAnExplicitSelection() async throws {
        let currentURL = URL(filePath: "/tmp/Current")
        let replacementURL = URL(filePath: "/tmp/Replacement")
        let current = repository(at: currentURL)
        let staleRefresh = repository(at: currentURL, head: .branch("stale"))
        let replacement = repository(
            at: replacementURL,
            head: .branch("replacement")
        )
        let stub = RepositoryServiceStub(
            snapshots: [
                currentURL: [current, staleRefresh],
                replacementURL: [replacement],
            ],
            delays: [replacementURL: .milliseconds(100)]
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(currentURL))

        let selection = Task {
            await state.handleRepositorySelection(.success(replacementURL))
        }
        await waitUntil { state.isLoadingRepository }
        #expect(state.isLoadingRepository)
        await state.refresh()
        await selection.value

        #expect(state.repository == replacement)
    }

    @Test
    @MainActor
    func successfulMutationReloadsRepositoryState() async throws {
        let repositoryURL = URL(filePath: "/tmp/Mutation")
        let before = repository(at: repositoryURL, head: .branch("main"))
        let after = repository(at: repositoryURL, head: .branch("renamed"))
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [before, after]]
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        await state.performMutation(["branch", "-m", "renamed"])

        #expect(state.repository == after)
    }

    @Test
    @MainActor
    func failedMutationStillReloadsRepositoryState() async throws {
        let repositoryURL = URL(filePath: "/tmp/FailedMutation")
        let before = repository(at: repositoryURL, head: .branch("main"))
        let after = repository(at: repositoryURL, head: .branch("recovered"))
        let failure = GitFailureDetails(
            command: "\"git\" \"branch\"",
            output: "Mutation failed"
        )
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [before, after]],
            mutationError: .commandFailed(failure)
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        await state.performMutation(["branch", "recovered"])

        #expect(state.repository == after)
        guard case .mutationAlert(let error, _) = state.repositoryFailure else {
            Issue.record("Expected the mutation failure alert")
            return
        }
        #expect(error == .commandFailed(failure))
        #expect(state.isShowingRepositoryMutationError)
        #expect(state.repositoryFailureDetails == nil)

        state.showRepositoryMutationErrorDetails()

        #expect(!state.isShowingRepositoryMutationError)
        #expect(state.repositoryFailureDetails == failure)
    }

    @Test
    @MainActor
    func stagesAndUnstagesAnIndividualFileThenReloadsTrueState() async throws {
        let repositoryURL = URL(filePath: "/tmp/Stage Individual")
        let modified = RepositoryChange(path: "Sources/My File.swift", kind: .modified)
        let staged = repository(at: repositoryURL, stagedChanges: [modified])
        let unstaged = repository(at: repositoryURL, unstagedChanges: [modified])
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [unstaged, staged, unstaged]]
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        await state.stage(modified)
        await state.unstage(modified)

        #expect(await stub.recordedArguments() == [
            ["--literal-pathspecs", "add", "--", "Sources/My File.swift"],
            ["--literal-pathspecs", "restore", "--staged", "--", "Sources/My File.swift"],
        ])
        #expect(state.repository == unstaged)
    }

    @Test
    @MainActor
    func stagesAllEligiblePathsWithoutResolvingConflicts() async throws {
        let repositoryURL = URL(filePath: "/tmp/Stage All")
        let conflict = RepositoryChange(path: "conflict.txt", kind: .conflict)
        let renamed = RepositoryChange(path: "new name.txt", kind: .renamed(from: "old name.txt"))
        let untracked = RepositoryChange(path: "notes.txt", kind: .untracked)
        let before = repository(
            at: repositoryURL,
            unstagedChanges: [conflict, renamed, untracked]
        )
        let after = repository(
            at: repositoryURL,
            stagedChanges: [renamed, untracked],
            unstagedChanges: [conflict]
        )
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [before, after]])
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        await state.stageAll()

        #expect(await stub.recordedArguments() == [
            [
                "--literal-pathspecs", "add", "--", "new name.txt", "old name.txt", "notes.txt",
            ],
        ])
        #expect(state.repository == after)
    }

    @Test
    @MainActor
    func ordinaryStageActionRefusesAConflictWithoutRunningGit() async throws {
        let repositoryURL = URL(filePath: "/tmp/Conflict")
        let conflict = RepositoryChange(path: "conflict.txt", kind: .conflict)
        let repository = repository(at: repositoryURL, unstagedChanges: [conflict])
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [repository]])
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        await state.stage(conflict)

        #expect(await stub.recordedMutations().isEmpty)
        #expect(state.repository == repository)
    }

    @Test
    @MainActor
    func unstagesAllFilesOnAnUnbornBranchUsingTheIndexSafeCommand() async throws {
        let repositoryURL = URL(filePath: "/tmp/Unborn")
        let added = RepositoryChange(path: "first.txt", kind: .added)
        let before = repository(
            at: repositoryURL,
            head: .unbornBranch("main"),
            stagedChanges: [added]
        )
        let after = repository(
            at: repositoryURL,
            head: .unbornBranch("main"),
            unstagedChanges: [RepositoryChange(path: "first.txt", kind: .untracked)]
        )
        let stub = RepositoryServiceStub(snapshots: [repositoryURL: [before, after]])
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        await state.unstageAll()

        #expect(await stub.recordedArguments() == [
            [
                "--literal-pathspecs", "rm", "--cached", "-f", "--", "first.txt",
            ],
        ])
        #expect(state.repository == after)
    }

    @Test
    @MainActor
    func rejectsASecondMutationWhileTheFirstIsRunning() async throws {
        let repositoryURL = URL(filePath: "/tmp/Concurrent Mutation")
        let change = RepositoryChange(path: "file.txt", kind: .modified)
        let before = repository(at: repositoryURL, unstagedChanges: [change])
        let after = repository(at: repositoryURL, stagedChanges: [change])
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [before, after]],
            mutationDelay: .milliseconds(100)
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        let first = Task { await state.stage(change) }
        await waitUntil { state.isPerformingMutation }
        #expect(state.isPerformingMutation)
        await state.stage(change)
        await first.value

        #expect(await stub.recordedArguments() == [
            [
                "--literal-pathspecs", "add", "--", "file.txt",
            ],
        ])
        #expect(state.repository == after)
    }

    @Test
    @MainActor
    func cancellationDoesNotInterruptMutationOrAuthoritativeReload() async throws {
        let repositoryURL = URL(filePath: "/tmp/Cancelled Mutation")
        let change = RepositoryChange(path: "file.txt", kind: .modified)
        let before = repository(at: repositoryURL, unstagedChanges: [change])
        let after = repository(at: repositoryURL, stagedChanges: [change])
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [before, after]],
            mutationDelay: .milliseconds(50)
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        let mutation = Task { await state.stage(change) }
        await waitUntil { state.isPerformingMutation }
        #expect(state.isPerformingMutation)
        mutation.cancel()
        await mutation.value

        #expect(state.repository == after)
        #expect(state.repositoryFailure == nil)
    }

    @Test
    @MainActor
    func repositoryReplacementIsRejectedUntilMutationAndReloadFinish() async throws {
        let repositoryURL = URL(filePath: "/tmp/Mutation Repository")
        let replacementURL = URL(filePath: "/tmp/Replacement Repository")
        let change = RepositoryChange(path: "file.txt", kind: .modified)
        let before = repository(at: repositoryURL, unstagedChanges: [change])
        let after = repository(at: repositoryURL, stagedChanges: [change])
        let replacement = repository(at: replacementURL)
        let stub = RepositoryServiceStub(
            snapshots: [repositoryURL: [before, after], replacementURL: [replacement]],
            mutationDelay: .milliseconds(50)
        )
        let state = WorkspaceState(
            repositoryService: stub.service,
            userDefaults: defaults,
            launchArguments: ["--ui-testing"]
        )
        await state.handleRepositorySelection(.success(repositoryURL))

        let mutation = Task { await state.stage(change) }
        await waitUntil { state.isPerformingMutation }
        #expect(state.isPerformingMutation)
        await state.handleRepositorySelection(.success(replacementURL))
        await mutation.value

        #expect(state.repository == after)
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async {
        var attempts = 0
        while !condition() && attempts < 100 {
            attempts += 1
            await Task.yield()
        }
    }

    private func cleanupDefaults() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }
}
