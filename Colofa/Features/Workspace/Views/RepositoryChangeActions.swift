////
//  RepositoryChangeActions.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Everything one changed path offers, as menu content shared by its row's context menu and the
/// Diff pane's actions menu, so both surfaces can never drift apart.
struct RepositoryChangeActions: View {
    @Environment(WorkspaceState.self) private var state
    let change: RepositoryChange
    let isStaged: Bool

    var body: some View {
        RepositoryChangeActionButton(change: change, isStaged: isStaged)

        // Rendered by what the path is rather than by whether the action can run right now. A
        // Conflict and a Staged Change offer neither: choosing a side of a Conflict is always
        // explicit, and a Staged Change is unstaged rather than discarded.
        if let destructiveAction {
            Divider()
            Button(
                destructiveAction.confirmationLabel,
                systemImage: destructiveAction.symbolName,
                action: beginDestructiveAction
            )
            .disabled(!isDestructiveActionAvailable)
            .accessibilityIdentifier(destructiveAction.accessibilityIdentifier)
        }

        Divider()
        Button(.revealInFinder, systemImage: "folder", action: revealInFinder)
            .accessibilityIdentifier("repository.change.revealInFinder")
        Button(.copyPath, systemImage: "doc.on.doc", action: copyPath)
            .accessibilityIdentifier("repository.change.copyPath")
    }

    private var destructiveAction: DestructiveFileAction? {
        guard !isStaged, !change.isConflict else {
            return nil
        }
        return change.isUntracked ? .moveToTrash(change) : .discardChanges(change)
    }

    private var isDestructiveActionAvailable: Bool {
        switch destructiveAction {
        case .discardChanges: state.canDiscardChanges(change, isStaged: isStaged)
        case .moveToTrash: state.canMoveToTrash(change, isStaged: isStaged)
        case nil: false
        }
    }

    private func beginDestructiveAction() {
        switch destructiveAction {
        case .discardChanges: state.beginDiscardingChanges(change)
        case .moveToTrash: state.beginMovingToTrash(change)
        case nil: break
        }
    }

    private func revealInFinder() {
        Task {
            await state.revealInFinder(change)
        }
    }

    private func copyPath() {
        state.copyPath(change)
    }
}

private extension DestructiveFileAction {
    /// Deliberately here rather than on the action itself: which SF Symbol names an action is a
    /// presentation choice, and the action is what the Store acts on.
    var symbolName: String {
        switch self {
        case .discardChanges: "arrow.uturn.backward"
        case .moveToTrash: "trash"
        }
    }

    /// One identifier per action, so a UI test can ask whether *this* menu offers an action
    /// rather than whether the word appears anywhere in the process. A query by label reaches the
    /// system and app menu bars too, where Delete, Copy, and Cut all already exist.
    var accessibilityIdentifier: String {
        switch self {
        case .discardChanges: "repository.change.discardChanges"
        case .moveToTrash: "repository.change.moveToTrash"
        }
    }
}
