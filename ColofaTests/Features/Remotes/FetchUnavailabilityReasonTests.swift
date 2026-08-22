////
//  FetchUnavailabilityReasonTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Why a disabled Fetch is disabled, said before the command rather than after it.
struct FetchUnavailabilityReasonTests {
    private func evaluate(
        _ repository: RepositorySnapshot?,
        isMutating: Bool = false,
        isFetching: Bool = false
    ) -> FetchUnavailabilityReason? {
        FetchUnavailabilityReason.evaluate(
            repository: repository,
            isMutating: isMutating,
            isFetching: isFetching
        )
    }

    @Test
    func allowsAFetchOfAConfiguredRemote() {
        #expect(evaluate(fetchRepository()) == nil)
    }

    @Test
    func refusesWithoutARepository() {
        #expect(evaluate(nil) == .noRepository)
    }

    @Test
    func refusesWithoutARemoteToAsk() {
        #expect(evaluate(fetchRepository(remotes: [])) == .noRemotes)
    }

    @Test
    func refusesWhileAnotherCommandHoldsTheRepository() {
        #expect(evaluate(fetchRepository(), isMutating: true) == .mutationInProgress)
    }

    /// A Fetch already running is its own reason, so the toolbar offers to stop that one rather
    /// than blaming an unrelated command.
    @Test
    func reportsARunningFetchRatherThanAGenericMutation() {
        #expect(
            evaluate(fetchRepository(), isMutating: true, isFetching: true) == .fetchInProgress
        )
    }
}
