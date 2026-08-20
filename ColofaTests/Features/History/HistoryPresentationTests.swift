////
//  HistoryPresentationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct HistoryPresentationTests {
    /// Emptying the pane drops everything it was showing and points it at the Ref to read next.
    @Test
    func emptyingThePaneDropsEverythingItWasShowing() {
        let emptied = loadedPresentation().emptied(for: .tag("v1.0"))

        #expect(emptied.reference == .tag("v1.0"))
        #expect(emptied.state == nil)
        #expect(emptied.loadedKey == nil)
        #expect(emptied.loadedScope == nil)
        #expect(emptied.selectedCommitID == nil)
        #expect(emptied.commitDetail == nil)
        #expect(emptied.selectedFileID == nil)
        #expect(emptied.pageFailure == nil)
        #expect(emptied.pageCount == 1)
    }

    /// Emptying the pane invalidates both reads it could have in flight, not just the page.
    ///
    /// Both IDs carry on from where they were: an ID reset to zero is handed out again by the
    /// next read, and the stale answer holding it would then match and land in the pane that was
    /// emptied.
    @Test
    func emptyingThePaneInvalidatesTheCommitReadAsWellAsThePage() {
        let emptied = loadedPresentation().emptied(for: .tag("v1.0"))

        #expect(emptied.loadID == 4)
        #expect(emptied.commitDetailLoadID == 6)
    }

    /// A pane holding a page, a selected Commit, and a Diff, with a read outstanding for each.
    private func loadedPresentation() -> HistoryPresentation {
        var presentation = HistoryPresentation(reference: .localBranch("feature"))
        presentation.state = .loading
        presentation.loadedKey = HistoryKey(
            repositoryURL: URL(filePath: "/tmp/repository"),
            reference: .localBranch("feature")
        )
        presentation.loadedScope = .firstParent
        presentation.selectedCommitID = "aaaa"
        presentation.commitDetail = .loading
        presentation.selectedFileID = "file.txt"
        presentation.pageFailure = .notRepository
        presentation.pageCount = 3
        presentation.loadID = 3
        presentation.commitDetailLoadID = 5
        return presentation
    }
}
