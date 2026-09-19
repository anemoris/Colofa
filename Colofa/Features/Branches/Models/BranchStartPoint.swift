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
    ///
    /// Resolved to a full object ID once, when the dialog opens. Asking Git for `HEAD` at Create
    /// would follow HEAD wherever a Checkout, Commit, or Reset elsewhere moved it while the
    /// dialog was open, and create the Branch at a Commit the user was never shown.
    ///
    /// The object ID comes from the same read as the Summary whenever there is one, so the two
    /// always describe one Commit. A message Colofa cannot decode leaves no Summary, and the
    /// object ID Git reported alongside HEAD is used on its own.
    static func head(of repository: RepositorySnapshot) -> Self? {
        guard let objectID = repository.headCommit?.objectID ?? repository.headObjectID else {
            return nil
        }
        let label: String
        switch repository.head {
        case .unbornBranch:
            return nil
        case .branch(let name):
            label = name
        case .detached:
            label = String(objectID.prefix(12))
        }
        return Self(
            origin: .head,
            revision: objectID,
            label: label,
            summary: repository.headCommit?.summary ?? ""
        )
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
