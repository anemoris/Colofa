////
//  RepositoryServiceStub.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

actor RepositoryServiceStub {
    private let gitAvailability: GitAvailability
    private let delays: [URL: Duration]
    private let errors: [URL: RepositoryOpenError]
    private let mutationError: RepositoryOpenError?
    private let mutationDelay: Duration?
    private let diffResults: [String: DiffLoadResult]
    private let diffError: RepositoryOpenError?
    private let diffDelay: Duration?
    private let historyCommits: [GitReference: [HistoryCommit]]
    /// What the first-parent walk reports, when a test cares that the two walks differ.
    private let firstParentCommits: [GitReference: [HistoryCommit]]
    private let historyFailingOffsets: Set<Int>
    private let historyDelay: Duration?
    private let commitDetails: [String: HistoryCommitDetail]
    /// The names this fixture's Git refuses, so a test can drive the invalid-name answer without
    /// depending on Git's real rules, which the integration tests cover.
    private let invalidBranchNames: Set<String>
    /// What stands between the dialog and Git's answer, so a test can drive the case where the
    /// name was never the problem.
    private let branchNameValidationError: RepositoryOpenError?
    private let checkoutComparison: CheckoutComparison
    private let checkoutComparisonError: RepositoryOpenError?
    // Not private: the Fetch extension in RepositoryServiceStub+Fetch.swift owns everything a
    // command that contacts a remote answers with, and Swift keeps `private` within one file.

    /// Which remotes this fixture's Git excludes from a Fetch of every remote.
    let skippedRemotes: Set<String>
    let skippedRemotesError: RepositoryOpenError?
    /// The remotes whose Fetch fails, so partial success can be driven without a real network.
    let failingRemotes: Set<String>
    /// What every command that contacts a remote fails with, for a failure no remote name can
    /// express: a Pull's Fetch names none.
    let networkMutationError: RepositoryOpenError?
    /// What Git wrote while refusing, so a test can drive a refusal that names a tag and one
    /// that names something else entirely.
    let networkFailureOutput: String
    /// The questions this fixture's Git asks, one per command that contacts a remote, so a test
    /// can drive one prompt, several, or none.
    let authenticationPrompts: [String]
    /// What Git writes when a question went unanswered.
    let authenticationFailureOutput: String
    let networkMutationDelay: Duration?
    let tagConflict: TagFetchConflict
    let tagConflictError: RepositoryOpenError?
    /// How long the second, explanatory read blocks, so a test can act while it is known to
    /// still be out at the remote.
    let tagConflictDelay: Duration?
    private var snapshots: [URL: [RepositorySnapshot]]
    private var mutations: [RecordedMutation] = []
    private var diffRequests: [DiffLoadRequest] = []
    private var historyRequests: [HistoryPageRequest] = []
    private var commitDetailRequests: [HistoryCommitDetailRequest] = []
    private var branchNameRequests: [BranchNameValidationRequest] = []
    private var checkoutComparisonRequests: [CheckoutComparisonRequest] = []
    var networkMutations: [[String]] = []
    var tagConflictRequests: [TagConflictRequest] = []
    var askedPromptCount = 0
    var authenticationRequests: [AuthenticationRequest] = []
    var authenticationResponses: [AuthenticationResponse] = []

    /// What Git writes when a question went unanswered and it had no terminal to fall back to.
    static let declinedAuthenticationOutput =
        "fatal: could not read Password for 'https://example.invalid': terminal prompts disabled"

    struct RecordedMutation: Equatable, Sendable {
        let arguments: [String]
        let standardInput: String?
    }

    init(
        gitAvailability: GitAvailability = .available(URL(filePath: "/usr/bin/git")),
        snapshots: [URL: [RepositorySnapshot]] = [:],
        delays: [URL: Duration] = [:],
        errors: [URL: RepositoryOpenError] = [:],
        mutationError: RepositoryOpenError? = nil,
        mutationDelay: Duration? = nil,
        diffResults: [String: DiffLoadResult] = [:],
        diffError: RepositoryOpenError? = nil,
        diffDelay: Duration? = nil,
        historyCommits: [GitReference: [HistoryCommit]] = [:],
        firstParentCommits: [GitReference: [HistoryCommit]] = [:],
        historyFailingOffsets: Set<Int> = [],
        historyDelay: Duration? = nil,
        commitDetails: [String: HistoryCommitDetail] = [:],
        invalidBranchNames: Set<String> = [],
        branchNameValidationError: RepositoryOpenError? = nil,
        checkoutComparison: CheckoutComparison = .empty,
        checkoutComparisonError: RepositoryOpenError? = nil,
        skippedRemotes: Set<String> = [],
        skippedRemotesError: RepositoryOpenError? = nil,
        failingRemotes: Set<String> = [],
        networkMutationError: RepositoryOpenError? = nil,
        networkFailureOutput: String = "fatal: could not read from remote repository",
        authenticationPrompts: [String] = [],
        authenticationFailureOutput: String = RepositoryServiceStub.declinedAuthenticationOutput,
        networkMutationDelay: Duration? = nil,
        tagConflict: TagFetchConflict = .empty,
        tagConflictError: RepositoryOpenError? = nil,
        tagConflictDelay: Duration? = nil
    ) {
        self.gitAvailability = gitAvailability
        self.snapshots = snapshots
        self.delays = delays
        self.errors = errors
        self.mutationError = mutationError
        self.mutationDelay = mutationDelay
        self.diffResults = diffResults
        self.diffError = diffError
        self.diffDelay = diffDelay
        self.historyCommits = historyCommits
        self.firstParentCommits = firstParentCommits
        self.historyFailingOffsets = historyFailingOffsets
        self.historyDelay = historyDelay
        self.commitDetails = commitDetails
        self.invalidBranchNames = invalidBranchNames
        self.branchNameValidationError = branchNameValidationError
        self.checkoutComparison = checkoutComparison
        self.checkoutComparisonError = checkoutComparisonError
        self.skippedRemotes = skippedRemotes
        self.skippedRemotesError = skippedRemotesError
        self.failingRemotes = failingRemotes
        self.networkMutationError = networkMutationError
        self.networkFailureOutput = networkFailureOutput
        self.authenticationPrompts = authenticationPrompts
        self.authenticationFailureOutput = authenticationFailureOutput
        self.networkMutationDelay = networkMutationDelay
        self.tagConflict = tagConflict
        self.tagConflictError = tagConflictError
        self.tagConflictDelay = tagConflictDelay
    }

    nonisolated var service: RepositoryService {
        RepositoryService(
            availability: {
                self.gitAvailability
            },
            load: { url in
                try await self.load(url)
            },
            runMutation: { arguments, standardInput, _ in
                try await self.mutate(arguments, standardInput: standardInput)
            },
            loadDiff: { request in
                try await self.diff(request)
            },
            loadHistory: { request in
                try await self.history(request)
            },
            loadCommitDetail: { request in
                try await self.commitDetail(request)
            },
            validateBranchName: { request in
                try await self.validateBranchName(request)
            },
            loadCheckoutComparison: { request in
                try await self.comparison(request)
            },
            loadSkippedRemotes: { _ in
                try await self.skipped()
            },
            loadTagConflicts: { request in
                try await self.conflicts(request)
            },
            runNetworkMutation: { arguments, _, responder in
                try await self.networkMutate(arguments, answeredBy: responder)
            }
        )
    }

    private func validateBranchName(_ request: BranchNameValidationRequest) throws -> Bool {
        branchNameRequests.append(request)
        if let branchNameValidationError {
            throw branchNameValidationError
        }
        return !invalidBranchNames.contains(request.name)
    }

    private func comparison(
        _ request: CheckoutComparisonRequest
    ) throws -> CheckoutComparison {
        checkoutComparisonRequests.append(request)
        if let checkoutComparisonError {
            throw checkoutComparisonError
        }
        return checkoutComparison
    }

    private func load(_ url: URL) async throws -> RepositorySnapshot {
        if let delay = delays[url] {
            try await Task.sleep(for: delay)
        }
        if let error = errors[url] {
            throw error
        }
        guard var availableSnapshots = snapshots[url],
              let snapshot = availableSnapshots.first else {
            throw RepositoryOpenError.notRepository
        }

        if availableSnapshots.count > 1 {
            availableSnapshots.removeFirst()
            snapshots[url] = availableSnapshots
        }
        return snapshot
    }

    /// A confirmed request is answered with the rendered Diff the unconfirmed one refused, which
    /// is how the real loader behaves once the higher bound applies.
    private func diff(_ request: DiffLoadRequest) async throws -> DiffLoadResult {
        diffRequests.append(request)
        if let diffDelay {
            try await Task.sleep(for: diffDelay)
        }
        if let diffError {
            throw diffError
        }
        guard let result = diffResults[Self.diffKey(of: request.source)] else {
            throw RepositoryOpenError.notRepository
        }
        if request.isConfirmed, case .confirmationRequired(let summary) = result {
            return .diff(Diff(files: [], measurement: summary.measurement))
        }
        return result
    }

    /// Pages the fixture the same way Git does: from an offset into one walk, reporting whether
    /// anything follows the page rather than whether the page came back full.
    private func history(_ request: HistoryPageRequest) async throws -> HistoryPage {
        historyRequests.append(request)
        if let historyDelay {
            try await Task.sleep(for: historyDelay)
        }
        if historyFailingOffsets.contains(request.offset) {
            throw RepositoryOpenError.commandFailed(
                GitFailureDetails(command: "git log", output: "History read failed")
            )
        }
        let walk = request.scope == .firstParent
            ? firstParentCommits[request.reference] ?? historyCommits[request.reference]
            : historyCommits[request.reference]
        guard let commits = walk else {
            throw RepositoryOpenError.notRepository
        }
        guard request.offset < commits.count else {
            return HistoryPage(commits: [], hasMore: false)
        }
        let end = min(request.offset + request.pageSize, commits.count)
        return HistoryPage(
            commits: Array(commits[request.offset..<end]),
            hasMore: end < commits.count
        )
    }

    private func commitDetail(
        _ request: HistoryCommitDetailRequest
    ) async throws -> HistoryCommitDetail {
        commitDetailRequests.append(request)
        guard let detail = commitDetails[request.objectID] else {
            throw RepositoryOpenError.notRepository
        }
        return detail
    }

    /// A patch is keyed by the path it is about, and a whole Commit — which is about all of
    /// them — by its object ID.
    private nonisolated static func diffKey(of source: DiffSource) -> String {
        if let path = source.path {
            return path
        }
        if case .commit(let objectID, _, _) = source {
            return objectID
        }
        return ""
    }

    private func mutate(_ arguments: [String], standardInput: String?) async throws {
        mutations.append(RecordedMutation(arguments: arguments, standardInput: standardInput))
        if let mutationDelay {
            try await Task.sleep(for: mutationDelay)
        }
        if let mutationError {
            throw mutationError
        }
    }
}

/// Everything the fixture was asked to do, in the order it was asked.
extension RepositoryServiceStub {
    func recordedMutations() -> [RecordedMutation] {
        mutations
    }

    func recordedArguments() -> [[String]] {
        mutations.map(\.arguments)
    }

    func recordedDiffRequests() -> [DiffLoadRequest] {
        diffRequests
    }

    func recordedHistoryRequests() -> [HistoryPageRequest] {
        historyRequests
    }

    func recordedCommitDetailRequests() -> [HistoryCommitDetailRequest] {
        commitDetailRequests
    }

    func recordedBranchNameRequests() -> [BranchNameValidationRequest] {
        branchNameRequests
    }

    func recordedCheckoutComparisonRequests() -> [CheckoutComparisonRequest] {
        checkoutComparisonRequests
    }

}
