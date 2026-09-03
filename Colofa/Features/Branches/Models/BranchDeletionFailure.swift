////
//  BranchDeletionFailure.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why a Delete Branch did not happen, reported inside the confirmation rather than over it: the
/// Branch is what the user has to decide about, and an alert would take it away to say so.
nonisolated enum BranchDeletionFailure: Equatable, Sendable {
    /// Git refused the deletion itself, in Git's own sanitized words.
    case refused(GitFailureDetails)

    /// Git could not be asked what removing the Branch would cost.
    ///
    /// Its own case because nothing was refused and the Branch is not what went wrong: reporting
    /// a Git that could not be run as a Branch needing Force Delete would demand consent to
    /// something nobody established was destructive.
    case surveyFailed(GitFailureDetails)

    /// The confirmation is already about one Branch, so the message says what happened rather
    /// than repeating which Branch it happened to.
    var message: LocalizedStringResource {
        switch self {
        case .refused: .deleteBranchRefusedDescription
        case .surveyFailed: .deleteBranchCheckFailedDescription
        }
    }

    /// What Git wrote, which is what the confirmation keeps one scroll away.
    var details: GitFailureDetails {
        switch self {
        case .refused(let details), .surveyFailed(let details): details
        }
    }
}
