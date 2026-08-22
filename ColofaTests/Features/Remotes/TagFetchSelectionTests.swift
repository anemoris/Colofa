////
//  TagFetchSelectionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Which remote the Fetch Tags dialog opens on, which is a starting point rather than an answer.
struct TagFetchSelectionTests {
    @Test
    func preselectsOriginWhenTheRepositoryHasOne() throws {
        let selection = try #require(TagFetchSelection(remotes: ["backup", "origin", "mirror"]))

        #expect(selection.selectedRemote == "origin")
        #expect(selection.remotes == ["backup", "origin", "mirror"])
    }

    @Test
    func preselectsTheFirstRemoteWhenThereIsNoOrigin() throws {
        let selection = try #require(TagFetchSelection(remotes: ["backup", "mirror"]))

        #expect(selection.selectedRemote == "backup")
    }

    @Test
    func hasNothingToAskAboutWithoutARemote() {
        #expect(TagFetchSelection(remotes: []) == nil)
    }
}
