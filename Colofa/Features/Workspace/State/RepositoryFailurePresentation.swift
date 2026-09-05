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
    /// A Fetch of every remote that ran no command, or that one remote refused after another
    /// had already answered. The outcome names the remotes; Git's own output stays one click
    /// away, so an explanation Colofa assembled never stands in for what Git actually said.
    case fetchAlert(FetchOutcome)
    /// A Fetch Tags Git refused, with the local tags it kept when Colofa could name them.
    case tagFetchAlert(TagFetchConflict?, remote: String, error: RepositoryOpenError)
    /// A Pull whose Fetch answered but whose fast-forward could not run, because the current
    /// Branch and its upstream have each moved on. It offers no way to continue: which of Merge
    /// or Rebase to use is the decision this Pull refused to make on the user's behalf.
    case pullDivergedAlert(PullDivergence, error: RepositoryOpenError)
    /// A Pull Git refused because advancing the Branch would have overwritten local work, named
    /// path by path. Git's own output stays one click away, so an explanation Colofa assembled
    /// never stands in for what Git actually said.
    case pullBlockedAlert(CheckoutObstruction, error: RepositoryOpenError)
    /// A Publish or Push the remote refused rather than one that never reached the remote at all.
    /// Git's own output stays one click away, so an explanation Colofa assembled never stands in
    /// for what Git actually said.
    case pushRejectedAlert(
        PushRejection,
        branch: String,
        upstream: String,
        error: RepositoryOpenError
    )
    /// A Publish or Push Colofa refused before running it, because the remote resolves to this
    /// Repository or to more than one address. Nothing ran, so there is no Git output to expand.
    case pushDestinationAlert(PushDestinationRefusal)
    /// A path the file system, not Git, refused to remove or reveal. Nothing Git ran, so there is
    /// no command output to expand.
    case fileActionAlert(FileActionFailure)
    /// A command that failed over the connection's identity rather than over what it was asked
    /// to do. It offers no way to continue: a host key Colofa would accept on the user's behalf
    /// is a host key nobody checked.
    case authenticationAlert(AuthenticationFailure, error: RepositoryOpenError)
    case details(GitFailureDetails, message: LocalizedStringResource)

    var title: LocalizedStringResource? {
        switch self {
        case .repositoryOpenAlert(let error):
            error.title
        case .mutationAlert(_, let title):
            title
        case .checkoutRefusedAlert(_, let reference, _):
            .checkoutBlockedTitle(reference)
        case .fetchAlert(let outcome):
            outcome.title
        case .tagFetchAlert(let conflict, let remote, _):
            conflict == nil ? .fetchTagsFailed : .fetchTagsRefusedTitle(remote)
        case .pullDivergedAlert(let divergence, _):
            divergence.title
        case .pullBlockedAlert:
            .pullBlockedTitle
        case .pushRejectedAlert(let rejection, _, _, _):
            rejection.title
        case .pushDestinationAlert(let refusal):
            refusal.title
        case .authenticationAlert(let failure, _):
            failure.title
        case .fileActionAlert(let failure):
            failure.title
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
        case .fetchAlert(let outcome):
            outcome.message
        case .tagFetchAlert(let conflict, _, let error):
            conflict?.message ?? Self.mutationMessage(for: error)
        case .pullDivergedAlert(let divergence, _):
            divergence.message
        case .pullBlockedAlert(let obstruction, _):
            obstruction.pullMessage
        case .pushRejectedAlert(let rejection, let branch, let upstream, _):
            rejection.message(branch: branch, upstream: upstream)
        case .pushDestinationAlert(let refusal):
            refusal.message
        case .authenticationAlert(let failure, _):
            failure.message
        case .fileActionAlert(let failure):
            failure.message
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
        case .mutationAlert(let error, _), .checkoutRefusedAlert(_, _, let error),
            .tagFetchAlert(_, _, let error), .pullDivergedAlert(_, let error),
            .pullBlockedAlert(_, let error), .pushRejectedAlert(_, _, _, let error),
            .authenticationAlert(_, let error):
            error.failureDetails != nil
        case .fetchAlert(let outcome):
            outcome.error?.failureDetails != nil
        case .fileActionAlert, .pushDestinationAlert, .repositoryOpenAlert, .details:
            false
        }
    }

    /// Whether this is one of the alerts a command failure raises, which share one presentation:
    /// a title, a message, and the offer to read what Git actually wrote.
    var isMutationAlert: Bool {
        switch self {
        case .mutationAlert, .checkoutRefusedAlert, .fetchAlert, .tagFetchAlert,
            .pullDivergedAlert, .pullBlockedAlert, .pushRejectedAlert, .pushDestinationAlert,
            .authenticationAlert, .fileActionAlert:
            true
        case .repositoryOpenAlert, .details:
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
        case .checkoutRefusedAlert(let obstruction, _, let error):
            error.failureDetails.map { .details($0, message: obstruction.message) }
        case .fetchAlert(let outcome):
            outcome.error?.failureDetails.flatMap { details in
                outcome.message.map { .details(details, message: $0) }
            }
        case .tagFetchAlert(let conflict, _, let error):
            error.failureDetails.map {
                .details($0, message: conflict?.message ?? Self.mutationMessage(for: error))
            }
        case .pullDivergedAlert(let divergence, let error):
            error.failureDetails.map { .details($0, message: divergence.message) }
        case .pullBlockedAlert(let obstruction, let error):
            error.failureDetails.map { .details($0, message: obstruction.pullMessage) }
        case .pushRejectedAlert(let rejection, let branch, let upstream, let error):
            error.failureDetails.map {
                .details($0, message: rejection.message(branch: branch, upstream: upstream))
            }
        case .authenticationAlert(let failure, let error):
            error.failureDetails.map { .details($0, message: failure.message) }
        case .fileActionAlert, .pushDestinationAlert, .details:
            nil
        }
    }

    /// A mutation already names its own failure in the alert title, so a command failure explains
    /// the shared next step instead of repeating it.
    ///
    /// The exception is a program Git could not find. Nothing about the operation explains that,
    /// and the message is the only place it can be said — the title is still the operation the
    /// user asked for, because that is still what failed.
    ///
    /// The alerts that do not come through here are the ones where Colofa has already established
    /// what happened: a Checkout that named the local work it protected, a Push the remote
    /// refused, a host key nobody confirmed. Those failures are not this one, and reading them as
    /// a missing helper would replace an answer with a guess.
    private static func mutationMessage(
        for error: RepositoryOpenError
    ) -> LocalizedStringResource {
        if let missingHelper = error.missingHelper {
            missingHelper.message
        } else if case .commandFailed = error {
            .gitMutationFailedDescription
        } else {
            error.message
        }
    }
}
