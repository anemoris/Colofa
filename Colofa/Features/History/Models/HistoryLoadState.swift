////
//  HistoryLoadState.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What the History pane is showing for the selected Ref.
nonisolated enum HistoryLoadState: Equatable, Sendable {
    case loading
    case loaded(HistoryTimeline)
    /// An Unborn Branch. Nothing is reachable yet, which is a state rather than a failure, so
    /// Git is never asked to walk from a Ref that does not exist.
    case unborn
    case failed(RepositoryOpenError)

    var timeline: HistoryTimeline? {
        if case .loaded(let timeline) = self {
            return timeline
        }
        return nil
    }
}
