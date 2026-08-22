////
//  BranchCreationFailure.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why Git refused a New Branch, reported inside the dialog rather than over it: the name is what
/// the user has to change, and an alert would take it away to say so.
nonisolated enum BranchCreationFailure: Equatable, Sendable {
    /// The dialog asked for Checkout and Git refused it, because moving the working tree would
    /// have overwritten uncommitted work. The branch was not created either: `git switch
    /// --create` does both or neither.
    case checkoutBlocked(CheckoutObstruction)

    /// Anything else Git refused, reported in Git's own sanitized words.
    case commandFailed(GitFailureDetails)

    /// Git could not be asked whether the name is one it accepts.
    ///
    /// Its own case because nothing was created and the name is not what went wrong: reporting a
    /// Git that could not be run as an unacceptable name would blame the user for it.
    case nameCheckFailed(GitFailureDetails)

    /// The dialog is already about one branch, so the message says what happened rather than
    /// repeating which branch it happened to.
    var message: LocalizedStringResource {
        switch self {
        case .checkoutBlocked(let obstruction):
            obstruction.message
        case .commandFailed:
            .createBranchFailedDescription
        case .nameCheckFailed:
            .branchNameCheckFailedDescription
        }
    }

    /// What Git wrote, when the refusal was Git's own words rather than a state Colofa named.
    var details: GitFailureDetails? {
        switch self {
        case .checkoutBlocked:
            nil
        case .commandFailed(let details), .nameCheckFailed(let details):
            details
        }
    }
}
