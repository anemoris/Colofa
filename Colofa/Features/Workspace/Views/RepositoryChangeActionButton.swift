////
//  RepositoryChangeActionButton.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryChangeActionButton: View {
    @Environment(WorkspaceState.self) private var state
    let change: RepositoryChange
    let isStaged: Bool

    var body: some View {
        Button(
            isStaged ? .unstageFile : .stageFile,
            systemImage: isStaged ? "minus" : "plus",
            action: performAction
        )
        .disabled(isStaged ? !state.canUnstage(change) : !state.canStage(change))
        .help(helpText)
    }

    private var helpText: String {
        if change.isConflict {
            String(localized: .resolveConflictBeforeStaging)
        } else {
            String(localized: isStaged ? .unstageFile : .stageFile)
        }
    }

    private func performAction() {
        Task {
            if isStaged {
                await state.unstage(change)
            } else {
                await state.stage(change)
            }
        }
    }
}
