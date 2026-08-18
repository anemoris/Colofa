////
//  HistoryScope.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which walk History reads from the selected Ref.
///
/// Both are Git's own answers to different questions, not a filter Colofa applies afterwards, so
/// switching between them re-asks rather than hiding rows that were already read.
nonisolated enum HistoryScope: String, CaseIterable, Identifiable, Sendable {
    /// Every Commit that can be walked to, including the ones a merge brought in. This is what
    /// `git log <ref>` answers.
    case reachable
    /// Only the Ref's own line: at every merge the walk follows the first parent, so a side
    /// branch is represented by the merge that integrated it rather than by its Commits. This is
    /// what `git log --first-parent <ref>` answers.
    case firstParent

    var id: Self { self }

    var name: LocalizedStringResource {
        switch self {
        case .reachable: .historyScopeReachable
        case .firstParent: .historyScopeFirstParent
        }
    }
}
