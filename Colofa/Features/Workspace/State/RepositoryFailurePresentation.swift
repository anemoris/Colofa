////
//  RepositoryFailurePresentation.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

enum RepositoryFailurePresentation: Sendable {
    case repositoryOpenAlert(RepositoryOpenError)
    case mutationAlert(RepositoryOpenError, title: LocalizedStringResource)
    /// A Checkout Git refused because it would have overwritten local work, named path by path.
    /// Git's own output stays one click away, so an explanation Colofa assembled never stands in
    /// for what Git actually said.
    case checkoutRefusedAlert(
        CheckoutObstruction,
        reference: String,
        error: RepositoryOpenError
    )
    case details(GitFailureDetails, message: LocalizedStringResource)

    var title: LocalizedStringResource? {
        switch self {
        case .repositoryOpenAlert(let error):
            error.title
        case .mutationAlert(_, let title):
            title
        case .checkoutRefusedAlert(_, let reference, _):
            .checkoutBlockedTitle(reference)
        case .details:
            nil
        }
    }

    var message: LocalizedStringResource? {
        switch self {
        case .repositoryOpenAlert(let error):
            error.message
        case .mutationAlert(let error, _):
            Self.mutationMessage(for: error)
        case .checkoutRefusedAlert(let obstruction, _, _):
            obstruction.message
        case .details(_, let message):
            message
        }
    }

    var details: GitFailureDetails? {
        if case .details(let details, _) = self {
            details
        } else {
            nil
        }
    }

    var canShowDetails: Bool {
        switch self {
        case .mutationAlert(let error, _), .checkoutRefusedAlert(_, _, let error):
            error.failureDetails != nil
        case .repositoryOpenAlert, .details:
            false
        }
    }

    /// Whether this is one of the alerts a command failure raises, which share one presentation:
    /// a title, a message, and the offer to read what Git actually wrote.
    var isMutationAlert: Bool {
        switch self {
        case .mutationAlert, .checkoutRefusedAlert: true
        case .repositoryOpenAlert, .details: false
        }
    }

    /// The persistent details this alert can turn into, or `nil` when the command failure carried
    /// nothing to expand.
    var expandedDetails: Self? {
        switch self {
        case .repositoryOpenAlert(let error):
            error.failureDetails.map { .details($0, message: error.message) }
        case .mutationAlert(let error, _):
            error.failureDetails.map { .details($0, message: Self.mutationMessage(for: error)) }
        case .checkoutRefusedAlert(let obstruction, _, let error):
            error.failureDetails.map { .details($0, message: obstruction.message) }
        case .details:
            nil
        }
    }

    /// A mutation already names its own failure in the alert title, so a command failure explains
    /// the shared next step instead of repeating it.
    private static func mutationMessage(
        for error: RepositoryOpenError
    ) -> LocalizedStringResource {
        if case .commandFailed = error {
            .gitMutationFailedDescription
        } else {
            error.message
        }
    }
}
