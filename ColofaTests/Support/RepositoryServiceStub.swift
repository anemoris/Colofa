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
    private var snapshots: [URL: [RepositorySnapshot]]
    private var mutations: [RecordedMutation] = []

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
        mutationDelay: Duration? = nil
    ) {
        self.gitAvailability = gitAvailability
        self.snapshots = snapshots
        self.delays = delays
        self.errors = errors
        self.mutationError = mutationError
        self.mutationDelay = mutationDelay
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
            }
        )
    }

    func recordedMutations() -> [RecordedMutation] {
        mutations
    }

    func recordedArguments() -> [[String]] {
        mutations.map(\.arguments)
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
