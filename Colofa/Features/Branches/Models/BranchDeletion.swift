////
//  BranchDeletion.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One local Branch waiting for the confirmation that removes it.
///
/// Deleting a Branch removes a name, not History: every Commit it holds that another Ref also
/// holds survives it untouched, and so does its Remote-tracking Branch and whatever the remote
/// itself has. What a Delete can actually cost is the History only this Branch reaches, which is
/// why that count is what the confirmation is built around rather than the word "unmerged".
nonisolated struct BranchDeletion: Equatable, Sendable {
    let branch: String

    /// What Git said about the Branch when this question opened, which is what the confirmation
    /// is agreed against and what is asked again before anything is removed.
    let survey: BranchDeletionSurvey

    /// Off by default and never remembered. Pressing Delete means Git's safe deletion; dropping
    /// History nothing else holds is a separate thing the user asks for each time.
    var forcesDeletion = false

    /// Whether Git's safe deletion cannot carry this Branch, so Force Delete has to be ticked
    /// before Delete does anything at all.
    ///
    /// Set from the start for a Branch holding Commits no other Ref holds, because that is a
    /// refusal Colofa can already see coming and making the user read it first would teach them
    /// nothing. It is also set afterwards, for the narrower refusal only Git can give: a Branch
    /// merged into some other Ref but into neither HEAD nor its upstream holds nothing unique
    /// and is still one `git branch --delete` refuses.
    private(set) var isForceRequired: Bool

    /// Why the last attempt did not remove the Branch, or `nil` when nothing has gone wrong.
    private(set) var failure: BranchDeletionFailure?

    init(branch: String, survey: BranchDeletionSurvey) {
        self.branch = branch
        self.survey = survey
        isForceRequired = survey.holdsUniqueCommits
    }

    /// Whether Delete may run, which for a Branch Git's safe mode will not carry means the box
    /// has been ticked.
    var canDelete: Bool {
        !isForceRequired || forcesDeletion
    }

    /// The exact command Git runs.
    ///
    /// `--delete` is Git's own merged-history protection and stays the default; `--force` is
    /// added only for a Delete the user ticked the box for. Neither form names a remote or a
    /// Remote-tracking Branch, so neither can reach one: `git branch --delete` writes under
    /// `refs/heads/` and nowhere else.
    var arguments: [String] {
        forcesDeletion
            ? ["branch", "--delete", "--force", "--", branch]
            : ["branch", "--delete", "--", branch]
    }

    /// Records that Git refused the deletion, and requires the explicit force that could carry
    /// it.
    ///
    /// The already-given consent is deliberately left ticked: a refusal explains what stood in
    /// the way, and retracting an answer the user already gave would read as Colofa forgetting it
    /// rather than as asking again.
    mutating func recordRefusal(_ details: GitFailureDetails) {
        failure = .refused(details)
        isForceRequired = true
    }

    /// Records that Git could not be asked what removing the Branch would cost.
    ///
    /// Deliberately not a refusal: nothing was refused, so nothing here demands a force the user
    /// would be agreeing to on no evidence.
    mutating func recordSurveyFailure(_ details: GitFailureDetails) {
        failure = .surveyFailed(details)
    }

    mutating func clearFailure() {
        failure = nil
    }
}
