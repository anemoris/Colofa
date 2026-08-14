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
    private var snapshots: [URL: [RepositorySnapshot]]
    private var mutations: [RecordedMutation] = []
    private var diffRequests: [DiffLoadRequest] = []

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
        diffDelay: Duration? = nil
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
            }
        )
    }

    func recordedMutations() -> [RecordedMutation] {
        mutations
    }

    func recordedArguments() -> [[String]] {
        mutations.map(\.arguments)
    }

    func recordedDiffRequests() -> [DiffLoadRequest] {
        diffRequests
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
        guard let result = diffResults[request.source.path] else {
            throw RepositoryOpenError.notRepository
        }
        if request.isConfirmed, case .confirmationRequired(let summary) = result {
            return .diff(Diff(files: [], measurement: summary.measurement))
        }
        return result
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
