////
//  RepositoryOpenError.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

enum RepositoryOpenError: Error, Equatable, Sendable {
    case gitUnavailable
    case locationUnavailable
    case notRepository
    case bareRepository
    case commandFailed(GitFailureDetails)

    var title: LocalizedStringResource {
        switch self {
        case .gitUnavailable:
            .gitUnavailable
        case .locationUnavailable:
            .repositoryLocationUnavailable
        case .notRepository:
            .notARepository
        case .bareRepository:
            .bareRepositoryUnsupported
        case .commandFailed:
            .repositoryOpenFailed
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .gitUnavailable:
            .gitUnavailableDescription
        case .locationUnavailable:
            .repositoryLocationUnavailableDescription
        case .notRepository:
            .notARepositoryDescription
        case .bareRepository:
            .bareRepositoryUnsupportedDescription
        case .commandFailed:
            // A program Git could not find explains the failure better than anything the
            // interrupted work can say about itself, which is usually nothing the user can act on.
            missingHelper?.message ?? .gitCommandFailedDescription
        }
    }

    var failureDetails: GitFailureDetails? {
        if case .commandFailed(let details) = self {
            details
        } else {
            nil
        }
    }

    /// The program Git looked for and could not run, when this failure's own output names one.
    ///
    /// Read out of the output rather than carried, because nothing along the way knew it: Git
    /// reports this failure as whatever it was doing when the missing program stopped it.
    var missingHelper: GitMissingHelper? {
        failureDetails.flatMap { GitMissingHelper.detect(in: $0.output) }
    }
}
