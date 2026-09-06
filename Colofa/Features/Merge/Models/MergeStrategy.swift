////
//  MergeStrategy.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which of Git's three merge policies one Merge runs under, and the exact command each is.
///
/// Three choices and no advanced panel: the option that decides whether History keeps a merge
/// Commit is the whole of what a user chooses between, and everything else Git can be told about
/// a merge is deliberately absent. Nothing here squashes, skips the Commit, skips a Hook, or
/// allows unrelated histories.
nonisolated enum MergeStrategy: CaseIterable, Identifiable, Sendable {
    /// Fast-forward when Git can, and create a merge Commit when it cannot.
    case automatic

    /// Fast-forward or refuse, which is the same promise a Pull makes.
    case fastForwardOnly

    /// Record a merge Commit even where a fast-forward was possible.
    case alwaysCreateMergeCommit

    /// What the dialog opens on, which is ordinary Git behavior.
    static let preselected = Self.automatic

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .automatic: .mergeStrategyDefault
        case .fastForwardOnly: .mergeStrategyFastForwardOnly
        case .alwaysCreateMergeCommit: .mergeStrategyAlwaysCommit
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .automatic: .mergeStrategyDefaultDescription
        case .fastForwardOnly: .mergeStrategyFastForwardOnlyDescription
        case .alwaysCreateMergeCommit: .mergeStrategyAlwaysCommitDescription
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .automatic: "repository.merge.strategy.default"
        case .fastForwardOnly: "repository.merge.strategy.fastForwardOnly"
        case .alwaysCreateMergeCommit: "repository.merge.strategy.alwaysCommit"
        }
    }

    /// The command this strategy runs against `source`.
    ///
    /// Every part of it is spelled out rather than inherited. `--ff`, `--ff-only`, and `--no-ff`
    /// are what make the chosen policy the policy, overruling a configured `merge.ff` that would
    /// otherwise turn Default into one of the other two. `--no-autostash` is there because
    /// `merge.autoStash` is a configuration Colofa would otherwise inherit: with it set, Git
    /// stashes the working tree, merges, and re-applies — a Stash nobody asked for. `--no-edit`
    /// keeps a button press from launching an editor Colofa has no window for. `--` keeps the
    /// revision out of Git's option parser.
    func arguments(merging source: MergeSource) -> [String] {
        [
            "merge", option, "--no-edit", "--no-autostash",
            "-m", source.commitMessage, "--", source.revision,
        ]
    }

    private var option: String {
        switch self {
        case .automatic: "--ff"
        case .fastForwardOnly: "--ff-only"
        case .alwaysCreateMergeCommit: "--no-ff"
        }
    }
}
