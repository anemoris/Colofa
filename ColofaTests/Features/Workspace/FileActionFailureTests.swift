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
    /// A cancellation is not a failure, and the difference has to reach the user: the file is
    /// where it was either way, but only one of the two is something to correct.
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
                == "“notes.txt” is still where it was. You don’t have permission."
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
