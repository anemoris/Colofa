////
//  RepositoryServiceStub+Stashes.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// What the fixture answers about Stashes.
///
/// Grouped apart from the fixture's body for the reason the branch and Fetch answers are: the
/// body says what the fixture is, and each extension says what one kind of read answers with.
extension RepositoryServiceStub {
    func stashes() async throws -> [Stash] {
        if let stashDelay {
            try await Task.sleep(for: stashDelay)
        }
        if let stashesError {
            throw stashesError
        }
        guard let list = stashLists.first else {
            return []
        }
        if stashLists.count > 1 {
            stashLists.removeFirst()
        }
        return list
    }

    func stashDetail(_ request: StashDetailRequest) throws -> StashDetail {
        stashDetailRequests.append(request)
        if let stashDetailError {
            throw stashDetailError
        }
        guard let detail = stashDetails[request.objectID] else {
            throw RepositoryOpenError.notRepository
        }
        return detail
    }

    func recordedStashDetailRequests() -> [StashDetailRequest] {
        stashDetailRequests
    }
}
