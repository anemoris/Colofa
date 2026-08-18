////
//  HistoryRefLabel.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One Ref Git reported as pointing at a Commit.
nonisolated struct HistoryRefLabel: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case head
        case localBranch
        case remoteBranch
        case tag
    }

    let name: String
    let kind: Kind

    var id: String { "\(kind).\(name)" }

    var systemImage: String {
        switch kind {
        case .head: "location"
        case .localBranch, .remoteBranch: "arrow.triangle.branch"
        case .tag: "tag"
        }
    }

    /// What the label is, spelled out for VoiceOver, so the icon is never the only thing that
    /// says whether this is a tag or a branch.
    var accessibilityName: LocalizedStringResource {
        switch kind {
        case .head: .head
        case .localBranch: .historyRefLocalBranch
        case .remoteBranch: .historyRefRemoteBranch
        case .tag: .historyRefTag
        }
    }
}
