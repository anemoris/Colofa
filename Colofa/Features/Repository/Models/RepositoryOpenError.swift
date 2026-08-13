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
            .gitCommandFailedDescription
        }
    }

    var failureDetails: GitFailureDetails? {
        if case .commandFailed(let details) = self {
            details
        } else {
            nil
        }
    }
}
