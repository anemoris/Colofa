////
//  FetchOutcomeTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a Fetch reports about itself, including the answers that are neither success nor failure.
struct FetchOutcomeTests {
    private let error = RepositoryOpenError.commandFailed(
        GitFailureDetails(
            command: "git fetch",
            output: "could not read from remote",
            exitStatus: 128
        )
    )

    @Test
    func aCompletedFetchIsTheOneThatRecordsATime() {
        #expect(FetchOutcome.fetched(["origin"]).isSuccessful)
        #expect(!FetchOutcome.fetched([]).isSuccessful)
        #expect(!FetchOutcome.cancelled(fetched: ["origin"]).isSuccessful)
        #expect(
            !FetchOutcome.failed(remotes: ["m"], fetched: ["origin"], error: error).isSuccessful
        )
        #expect(!FetchOutcome.nothingEligible.isSuccessful)
        #expect(!FetchOutcome.planFailed(error).isSuccessful)
    }

    /// A Fetch the user stopped needs no alert explaining what the user just did.
    @Test
    func saysNothingAboutASuccessOrACancellation() {
        #expect(!FetchOutcome.fetched(["origin"]).needsReporting)
        #expect(!FetchOutcome.cancelled(fetched: []).needsReporting)
        #expect(FetchOutcome.nothingEligible.needsReporting)
        #expect(FetchOutcome.planFailed(error).needsReporting)
        #expect(FetchOutcome.failed(remotes: ["m"], fetched: [], error: error).needsReporting)
    }

    @Test
    func carriesGitsOwnFailureOnlyWhenGitProducedOne() {
        #expect(FetchOutcome.failed(remotes: ["m"], fetched: [], error: error).error == error)
        #expect(FetchOutcome.planFailed(error).error == error)
        #expect(FetchOutcome.nothingEligible.error == nil)
        #expect(FetchOutcome.fetched(["origin"]).error == nil)
    }

    /// The remote that failed is named, and a Fetch where others answered says so.
    @Test
    func namesTheFailingRemotesAndDistinguishesAPartialFetch() throws {
        let total = FetchOutcome.failed(remotes: ["mirror"], fetched: [], error: error)
        let partial = FetchOutcome.failed(remotes: ["mirror"], fetched: ["origin"], error: error)

        let totalMessage = String(localized: try #require(total.message))
        let partialMessage = String(localized: try #require(partial.message))
        #expect(totalMessage.contains("mirror"))
        #expect(partialMessage.contains("mirror"))
        #expect(totalMessage != partialMessage)
        #expect(try #require(total.title) == LocalizedStringResource.fetchFailed)
    }

    @Test
    func namesEveryFailingRemote() throws {
        let outcome = FetchOutcome.failed(
            remotes: ["mirror", "backup"],
            fetched: [],
            error: error
        )

        let message = String(localized: try #require(outcome.message))
        #expect(message.contains("mirror"))
        #expect(message.contains("backup"))
    }

    @Test
    func aSuccessAndACancellationHaveNothingToSay() {
        #expect(FetchOutcome.fetched(["origin"]).title == nil)
        #expect(FetchOutcome.fetched(["origin"]).message == nil)
        #expect(FetchOutcome.cancelled(fetched: []).title == nil)
        #expect(FetchOutcome.cancelled(fetched: []).message == nil)
    }
}
