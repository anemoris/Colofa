////
//  PushOutcomeTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What one Publish or Push reports, and which of those answers carries Git's own words.
struct PushOutcomeTests {
    private static let failure = RepositoryOpenError.commandFailed(
        GitFailureDetails(command: "git push", output: "rejected", exitStatus: 1)
    )

    @Test
    func afailedPushCarriesGitsOwnWords() {
        let outcome = PushOutcome.failed(Self.failure)

        #expect(outcome.error == Self.failure)
    }

    /// A Push that worked and one the user stopped both have nothing for an alert to say.
    @Test(arguments: [PushOutcome.succeeded, .cancelled])
    func nothingIsCarriedByApushThatWorkedOrOneTheUserStopped(_ outcome: PushOutcome) {
        #expect(outcome.error == nil)
    }
}
