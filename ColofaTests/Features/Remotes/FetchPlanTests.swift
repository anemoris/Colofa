////
//  FetchPlanTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Which remotes a Fetch of every remote contacts, which is Git's answer rather than Colofa's.
struct FetchPlanTests {
    private func remotes(_ names: [String]) -> [RepositoryRemote] {
        names.map { RepositoryRemote(name: $0, url: "ssh://example.invalid/\($0).git") }
    }

    @Test
    func contactsEveryRemoteTheRepositoryLists() {
        let plan = FetchPlan.evaluate(remotes: remotes(["origin", "mirror"]), skipping: [])

        #expect(plan.remotes == ["origin", "mirror"])
        #expect(!plan.isEmpty)
    }

    @Test
    func leavesOutTheRemotesGitExcludes() {
        let plan = FetchPlan.evaluate(
            remotes: remotes(["origin", "mirror", "backup"]),
            skipping: ["mirror"]
        )

        #expect(plan.remotes == ["origin", "backup"])
    }

    /// A Repository whose every remote is excluded is a Fetch with no command to run, which is
    /// not the same as a Fetch that ran and found nothing.
    @Test
    func reportsAnEmptyPlanWhenEveryRemoteIsExcluded() {
        let plan = FetchPlan.evaluate(
            remotes: remotes(["origin", "mirror"]),
            skipping: ["origin", "mirror"]
        )

        #expect(plan.remotes.isEmpty)
        #expect(plan.isEmpty)
    }

    /// A name that is skipped in configuration but no longer configured as a remote changes
    /// nothing: the Repository's own list is what is being filtered.
    @Test
    func ignoresAnExcludedNameThatIsNotARemote() {
        let plan = FetchPlan.evaluate(remotes: remotes(["origin"]), skipping: ["gone"])

        #expect(plan.remotes == ["origin"])
    }
}
