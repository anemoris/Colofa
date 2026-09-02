////
//  DestructiveFileAction.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One destructive action against a changed path, waiting for the confirmation that runs it.
///
/// The two are separate cases rather than one action with a flag because they are different
/// operations on different content: Discard Changes restores tracked content Git already has a
/// copy of, and Move to Trash removes a file Git has never seen. Naming them apart is what keeps
/// an untracked file from being removed by something called Discard Changes.
enum DestructiveFileAction: Equatable, Sendable {
    /// Restores the unstaged content of a tracked, non-conflicted path to its staged version.
    case discardChanges(RepositoryChange)
    /// Moves an untracked path to the macOS Trash, where it stays recoverable.
    case moveToTrash(RepositoryChange)

    var change: RepositoryChange {
        switch self {
        case .discardChanges(let change), .moveToTrash(let change): change
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .discardChanges(let change): .discardChangesConfirmTitle(change.path)
        case .moveToTrash(let change): .moveToTrashConfirmTitle(change.path)
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .discardChanges: .discardChangesConfirmMessage
        case .moveToTrash: .moveToTrashConfirmMessage
        }
    }

    var confirmationLabel: LocalizedStringResource {
        switch self {
        case .discardChanges: .discardChanges
        case .moveToTrash: .moveToTrash
        }
    }
}
