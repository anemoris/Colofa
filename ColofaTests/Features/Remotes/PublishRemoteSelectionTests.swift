////
//  PublishRemoteSelectionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Which remote the Publish dialog opens on, when it has to open at all.
struct PublishRemoteSelectionTests {

    /// `origin` is the name Git itself gives the remote a clone came from, so it is where the
    /// dialog starts however the remotes happen to be ordered.
    @Test
    func originIsPreselectedWhereverItAppears() {
        let selection = PublishRemoteSelection(branch: "main", remotes: ["mirror", "origin"])

        #expect(selection?.selectedRemote == "origin")
        #expect(selection?.remotes == ["mirror", "origin"])
    }

    /// Without one, the dialog still has to start somewhere, and the first remote is the only
    /// answer that is not a guess about the user's intent.
    @Test
    func thefirstRemoteIsUsedWhereThereIsNoOrigin() {
        let selection = PublishRemoteSelection(branch: "main", remotes: ["mirror", "backup"])

        #expect(selection?.selectedRemote == "mirror")
    }

    /// A Repository with no remote has nothing to ask about, so there is no dialog to open.
    @Test
    func norepositoryWithoutAremoteEverOpensThedialog() {
        #expect(PublishRemoteSelection(branch: "main", remotes: []) == nil)
    }

    // MARK: - Still describing the Repository

    @Test
    func areloadThatChangedNothingLeavesThedialogStanding() throws {
        let selection = try #require(
            PublishRemoteSelection(branch: "main", remotes: ["origin", "mirror"])
        )

        #expect(
            selection.describes(pushRepository(upstream: nil, remotes: ["origin", "mirror"]))
        )
    }

    /// Each of the three things this dialog assumes, stopped from being true one at a time: the
    /// Branch it is about, the fact that nobody has published it, and the remote it would use.
    @Test
    func achangedBranchUpstreamOrRemoteStopsDescribingTheRepository() throws {
        let selection = try #require(
            PublishRemoteSelection(branch: "main", remotes: ["origin", "mirror"])
        )

        #expect(
            !selection.describes(
                pushRepository(head: .branch("other"), upstream: nil, remotes: ["origin"])
            )
        )
        #expect(!selection.describes(pushRepository(remotes: ["origin", "mirror"])))
        #expect(!selection.describes(pushRepository(upstream: nil, remotes: ["mirror"])))
    }
}
