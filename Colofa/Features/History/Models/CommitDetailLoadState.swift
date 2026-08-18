////
//  CommitDetailLoadState.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What the Commit detail is showing for the selected Commit.
nonisolated enum CommitDetailLoadState: Equatable, Sendable {
    case loading
    case loaded(HistoryCommitDetail)
    case failed(RepositoryOpenError)

    var detail: HistoryCommitDetail? {
        if case .loaded(let detail) = self {
            return detail
        }
        return nil
    }
}
