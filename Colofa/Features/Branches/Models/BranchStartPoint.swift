////
//  BranchStartPoint.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The Commit a new local Branch starts at.
///
/// Colofa never chooses one: New Branch starts at whatever HEAD points at, and Create Branch Here
/// starts at the Commit the user selected in History. Either way the dialog shows it read-only,
/// so the created ref is predictable rather than inferred from whichever pane was open.
nonisolated struct BranchStartPoint: Equatable, Sendable {
    enum Origin: Equatable, Sendable {
        /// Whatever HEAD points at, which the toolbar's New Branch starts from.
        case head
        /// One Commit selected in History.
        case commit
    }

    let origin: Origin

    /// What Git is asked to start the branch at.
    let revision: String

    /// What the read-only row names: the current branch, or the abbreviated Commit Git reported.
    let label: String

    /// The start Commit's Summary, or empty when Colofa has not read one.
    let summary: String

    /// The start point HEAD names, or `nil` on an Unborn Branch, which names no Commit at all.
    static func head(of repository: RepositorySnapshot) -> Self? {
        switch repository.head {
        case .unbornBranch:
            nil
        case .branch(let name):
            Self(
                origin: .head,
                revision: "HEAD",
                label: name,
                summary: repository.headCommit?.summary ?? ""
            )
        case .detached(let objectID):
            Self(
                origin: .head,
                revision: "HEAD",
                label: String(objectID.prefix(12)),
                summary: repository.headCommit?.summary ?? ""
            )
        }
    }

    /// The start point one selected Commit names. The full object ID is what Git is asked for,
    /// because the abbreviation a row shows is only unique at the time it was read.
    static func commit(_ commit: HistoryCommit) -> Self {
        Self(
            origin: .commit,
            revision: commit.objectID,
            label: commit.abbreviatedObjectID,
            summary: commit.summary
        )
    }

    /// What kind of start point this is, spelled out so the dialog never leaves it to an icon.
    var kind: LocalizedStringResource {
        switch origin {
        case .head: .branchStartPointHead
        case .commit: .branchStartPointCommit
        }
    }
}
