////
//  FetchUnavailabilityReason.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why Fetch or Fetch Tags cannot run right now, so a disabled control explains itself instead of
/// letting the command fail afterwards.
///
/// A remote Git's configuration excludes from a Fetch of every remote is deliberately absent:
/// that answer lives in configuration Colofa reads when Fetch runs, not in a snapshot, and it is
/// reported as an outcome rather than as a disabled button.
nonisolated enum FetchUnavailabilityReason: Equatable, Sendable {
    case noRepository
    case noRemotes
    case mutationInProgress
    case fetchInProgress

    /// Why a Fetch cannot start, or `nil` when it may.
    static func evaluate(
        repository: RepositorySnapshot?,
        isMutating: Bool,
        isFetching: Bool
    ) -> Self? {
        guard let repository else {
            return .noRepository
        }
        if repository.remotes.isEmpty {
            return .noRemotes
        }
        if isFetching {
            return .fetchInProgress
        }
        return isMutating ? .mutationInProgress : nil
    }

    var message: LocalizedStringResource {
        switch self {
        case .noRepository: .fetchUnavailableNoRepository
        case .noRemotes: .fetchUnavailableNoRemotes
        case .mutationInProgress: .fetchUnavailableMutationInProgress
        case .fetchInProgress: .fetchUnavailableFetchInProgress
        }
    }
}
