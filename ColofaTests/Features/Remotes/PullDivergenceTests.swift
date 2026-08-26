////
//  PullDivergenceTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Reading a divergence out of the Repository as it is after the Pull's Fetch, rather than out of
/// a message Git translated.
struct PullDivergenceTests {
    @Test
    @MainActor
    func readsBothCountsFromTheCurrentBranch() throws {
        let divergence = try #require(
            PullDivergence.evaluate(in: pullRepository(ahead: 2, behind: 3))
        )

        #expect(divergence.branch == "main")
        #expect(divergence.upstream == "origin/main")
        #expect(divergence.ahead == 2)
        #expect(divergence.behind == 3)
    }

    /// A Branch that is only behind is one a fast-forward handles, so whatever refused this Pull
    /// was something else.
    @Test
    @MainActor
    func reportsNoDivergenceForABranchThatIsOnlyBehind() {
        #expect(PullDivergence.evaluate(in: pullRepository(ahead: 0, behind: 3)) == nil)
    }

    @Test
    @MainActor
    func reportsNoDivergenceForABranchThatIsOnlyAhead() {
        #expect(PullDivergence.evaluate(in: pullRepository(ahead: 2, behind: 0)) == nil)
    }

    @Test
    @MainActor
    func reportsNoDivergenceWithoutAnUpstream() {
        #expect(PullDivergence.evaluate(in: pullRepository(upstream: nil)) == nil)
    }

    /// Detached HEAD is on no Branch, so there is no Branch for an upstream to have diverged from.
    @Test
    @MainActor
    func reportsNoDivergenceOnDetachedHead() {
        #expect(
            PullDivergence.evaluate(
                in: pullRepository(head: .detached("0123456789"), ahead: 2, behind: 3)
            ) == nil
        )
    }

    /// The alert quotes the same two numbers the status bar is showing, and names the two
    /// commands that can integrate them.
    @Test
    @MainActor
    func namesBothRefsTheCountsAndTheWayOut() throws {
        let divergence = try #require(
            PullDivergence.evaluate(in: pullRepository(ahead: 2, behind: 3))
        )

        let title = englishText(divergence.title)
        #expect(title.contains("main"))
        #expect(title.contains("origin/main"))

        let message = englishText(divergence.message)
        #expect(message.contains("2"))
        #expect(message.contains("3"))
        #expect(message.contains("Merge"))
        #expect(message.contains("Rebase"))
    }
}
