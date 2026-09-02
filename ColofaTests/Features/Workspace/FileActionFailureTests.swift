////
//  FileActionFailureTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct FileActionFailureTests {
    /// A cancellation is not a failure, and the difference has to reach the user. Only the
    /// cancellation says where the file is: nothing declined it, so it is still where it was.
    /// A refusal names the action that did not happen instead, because a path something else
    /// already removed fails the same way and is not there to promise.
    @Test
    func cancellationAndRefusalReadDifferentlyAndBothKeepThePath() {
        let cancelled = FileActionFailure.trashCancelled(path: "notes.txt")
        let failed = FileActionFailure.trashFailed(
            path: "notes.txt",
            reason: "You don’t have permission."
        )

        #expect(englishText(cancelled.title) == "File Was Not Moved to the Trash")
        #expect(
            englishText(cancelled.message)
                == "The operation was cancelled, so “notes.txt” is still where it was."
        )
        #expect(englishText(failed.title) == "File Could Not Be Moved to the Trash")
        #expect(
            englishText(failed.message)
                == "Colofa could not move “notes.txt” to the Trash. You don’t have permission."
        )
    }

    @Test
    func aPathThatDisappearedSaysSoAndSaysTheRepositoryWasReadAgain() {
        let failure = FileActionFailure.revealMissing(path: "gone/away.txt")

        #expect(englishText(failure.title) == "File Could Not Be Revealed")
        #expect(
            englishText(failure.message)
                == "“gone/away.txt” is no longer on disk. Colofa reloaded the Repository."
        )
    }

    /// Both reach the window through the same slot every other command failure uses, and neither
    /// offers Git output to expand, because no Git command ran.
    @Test
    func aFileActionFailurePresentsAsAnAlertWithNothingToExpand() {
        let presentation = RepositoryFailurePresentation
            .fileActionAlert(.revealMissing(path: "gone.txt"))

        #expect(presentation.isMutationAlert)
        #expect(!presentation.canShowDetails)
        #expect(presentation.details == nil)
        #expect(presentation.expandedDetails == nil)
    }
}
