////
//  WorkspaceStateHistoryCopyTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Copy puts the values the user actually selected on the pasteboard.
@MainActor
struct WorkspaceStateHistoryCopyTests {
    @Test
    func copyingCopiesTheSelectedSHAAndBranchName() async {
        let pasteboard = PasteboardRecorder()
        let stub = historyStub()
        let state = await historyWorkspace(stub, pasteboard: pasteboard)
        state.sidebarSelection = .reference(.localBranch("feature"))
        await state.loadHistory()
        state.selectedCommitID = historyObjectID(1, prefix: "f")

        state.copyCommitObjectID()
        state.copyBranchName()

        #expect(pasteboard.written == [historyObjectID(1, prefix: "f"), "feature"])
    }

    /// HEAD names whichever branch it points at, and a tag names none at all.
    @Test
    func onlyARefThatNamesABranchOffersItsName() async {
        let pasteboard = PasteboardRecorder()
        let stub = historyStub()
        let state = await historyWorkspace(stub, pasteboard: pasteboard)

        #expect(state.copyableBranchName == "main")

        state.sidebarSelection = .reference(.tag("v1.0"))
        #expect(state.copyableBranchName == nil)
        state.copyBranchName()
        #expect(pasteboard.written.isEmpty)
    }

    @Test
    func nothingIsCopiedWhenNoCommitIsSelected() async {
        let pasteboard = PasteboardRecorder()
        let state = await historyWorkspace(historyStub(), pasteboard: pasteboard)

        #expect(state.copyableCommitObjectID == nil)
        state.copyCommitObjectID()

        #expect(pasteboard.written.isEmpty)
    }
}
