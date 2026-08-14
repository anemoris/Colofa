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
    case details(GitFailureDetails, message: LocalizedStringResource)

    var title: LocalizedStringResource? {
        switch self {
        case .repositoryOpenAlert(let error):
            error.title
        case .mutationAlert(_, let title):
            title
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
        if case .mutationAlert(let error, _) = self {
            error.failureDetails != nil
        } else {
            false
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
