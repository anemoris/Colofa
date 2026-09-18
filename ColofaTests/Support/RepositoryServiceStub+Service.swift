////
//  RepositoryServiceStub+Service.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// The fixture seen as the `RepositoryService` the Store is built with.
///
/// Kept apart from the fixture's body so that body stays about what the fixture holds rather than
/// about how each of its answers is wired up.
extension RepositoryServiceStub {
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
            loadStashes: { _ in
                try await self.stashes()
            },
            loadStashDetail: { request in
                try await self.stashDetail(request)
            },
            validateBranchName: { request in
                try await self.validateBranchName(request)
            },
            loadCheckoutComparison: { request in
                try await self.comparison(request)
            },
            loadBranchDeletionSurvey: { request in
                try await self.deletionSurvey(request)
            },
            loadSkippedRemotes: { _ in
                try await self.skipped()
            },
            loadTagConflicts: { request in
                try await self.conflicts(request)
            },
            loadPublishRemote: { request in
                try await self.configuredPublishRemote(request)
            },
            loadPushTarget: { request in
                try await self.configuredPushTarget(request)
            },
            loadPushDestination: { request in
                try await self.configuredPushDestination(request)
            },
            runNetworkMutation: { arguments, _, responder in
                try await self.networkMutate(arguments, answeredBy: responder)
            }
        )
    }
}
