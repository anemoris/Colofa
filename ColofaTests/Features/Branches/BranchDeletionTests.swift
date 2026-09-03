////
//  BranchDeletionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The pending Delete itself: which command it produces, and when the explicit force is required
/// before it produces one at all.
struct BranchDeletionTests {
    private static func deletion(
        uniqueCommitCount: Int,
        objectID: String = "abc"
    ) -> BranchDeletion {
        BranchDeletion(
            branch: "topic",
            survey: BranchDeletionSurvey(
                objectID: objectID,
                uniqueCommitCount: uniqueCommitCount
            )
        )
    }

    /// A Branch every other Ref already holds needs no force, and runs Git's own safe deletion.
    @Test
    func deletesAmergedBranchThroughGitsSafeMode() {
        let deletion = Self.deletion(uniqueCommitCount: 0)

        #expect(!deletion.isForceRequired)
        #expect(deletion.canDelete)
        #expect(deletion.arguments == ["branch", "--delete", "--", "topic"])
    }

    /// Commits nothing else holds are exactly what Git's safe deletion refuses to drop, so the
    /// checkbox is required from the moment the dialog opens.
    @Test
    func requiresForceForABranchHoldingCommitsNothingElseHolds() {
        var deletion = Self.deletion(uniqueCommitCount: 4)

        #expect(deletion.isForceRequired)
        #expect(!deletion.canDelete)
        #expect(deletion.survey.holdsUniqueCommits)

        deletion.forcesDeletion = true

        #expect(deletion.canDelete)
        #expect(deletion.arguments == ["branch", "--delete", "--force", "--", "topic"])
    }

    /// Force is off until the user says otherwise, whatever the Branch holds.
    @Test
    func startsWithForceOff() {
        #expect(!Self.deletion(uniqueCommitCount: 0).forcesDeletion)
        #expect(!Self.deletion(uniqueCommitCount: 9).forcesDeletion)
    }

    /// Git's own refusal is narrower than the count: a Branch merged into some other Ref but into
    /// neither HEAD nor its upstream holds nothing unique and is still one Git will not delete.
    @Test
    func requiresForceAfterGitRefusesABranchHoldingNothingUnique() {
        var deletion = Self.deletion(uniqueCommitCount: 0)

        deletion.recordRefusal(
            GitFailureDetails(command: "git branch", output: "not fully merged")
        )

        #expect(deletion.isForceRequired)
        #expect(!deletion.canDelete)
        #expect(
            deletion.failure
                == .refused(GitFailureDetails(command: "git branch", output: "not fully merged"))
        )
    }

    /// A refusal explains what stood in the way; it does not retract consent already given.
    @Test
    func keepsTheGivenForceConsentAcrossArefusal() {
        var deletion = Self.deletion(uniqueCommitCount: 2)
        deletion.forcesDeletion = true

        deletion.recordRefusal(GitFailureDetails(command: "git branch", output: "refused"))

        #expect(deletion.forcesDeletion)
        #expect(deletion.canDelete)
    }

    /// A read that could not be taken is not a refusal: nothing stood in the way, so nothing
    /// here asks for consent to a destructive command.
    @Test
    func recordsAfailedReadWithoutRequiringForce() {
        var deletion = Self.deletion(uniqueCommitCount: 0)

        deletion.recordSurveyFailure(
            GitFailureDetails(command: "git rev-list", output: "boom")
        )

        #expect(!deletion.isForceRequired)
        #expect(deletion.canDelete)
        #expect(
            deletion.failure
                == .surveyFailed(GitFailureDetails(command: "git rev-list", output: "boom"))
        )
    }

    @Test
    func clearsTheRecordedRefusal() {
        var deletion = Self.deletion(uniqueCommitCount: 0)
        deletion.recordRefusal(GitFailureDetails(command: "git branch", output: "refused"))

        deletion.clearFailure()

        #expect(deletion.failure == nil)
        // Clearing what Git wrote does not un-learn that Git refused.
        #expect(deletion.isForceRequired)
    }

    /// No command it builds can reach a remote, a Remote-tracking Branch, or a tag.
    @Test(arguments: [false, true])
    func neverNamesAnythingOutsideTheLocalBranch(_ forces: Bool) {
        var deletion = Self.deletion(uniqueCommitCount: 1)
        deletion.forcesDeletion = forces

        let arguments = deletion.arguments

        #expect(arguments.first == "branch")
        #expect(!arguments.contains("--remotes"))
        #expect(!arguments.contains("-r"))
        #expect(!arguments.contains(where: { $0.hasPrefix("refs/remotes/") }))
        #expect(arguments.last == "topic")
    }
}
