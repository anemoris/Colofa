////
//  DestructiveFileActionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct DestructiveFileActionTests {
    private let tracked = RepositoryChange(path: "src/app.swift", kind: .modified)
    private let untracked = RepositoryChange(path: "notes 备忘.txt", kind: .untracked)

    @Test
    func aDiscardNamesThePathAndPromisesStagedChangesSurvive() {
        let action = DestructiveFileAction.discardChanges(tracked)

        #expect(action.change == tracked)
        #expect(englishText(action.title) == "Discard changes to “src/app.swift”?")
        #expect(englishText(action.confirmationLabel) == "Discard Changes")
        #expect(englishText(action.message).contains("Staged Changes are kept."))
    }

    /// The two actions are told apart by name, not by wording: an untracked file is never removed
    /// by something called Discard Changes, and never called deleted either.
    @Test
    func aMoveToTrashNamesTheTrashRatherThanDiscardingOrDeleting() {
        let action = DestructiveFileAction.moveToTrash(untracked)

        #expect(action.change == untracked)
        #expect(englishText(action.title) == "Move “notes 备忘.txt” to the Trash?")
        #expect(englishText(action.confirmationLabel) == "Move to Trash")

        let message = englishText(action.message)
        #expect(message.contains("Trash"))
        #expect(!message.contains("Discard"))
        #expect(!message.contains("Delete"))
    }
}
