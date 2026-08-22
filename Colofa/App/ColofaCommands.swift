////
//  ColofaCommands.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct ColofaCommands: Commands {
    let state: WorkspaceState

    var body: some Commands {
        @Bindable var state = state

        // The initial release is single-window; opening a Repository replaces the active session.
        // Replacing .newItem also removes New Window: the initial app is
        // single-window and single-Repository per the workflow spec.
        CommandGroup(replacing: .newItem) {
            Button(String(localized: .openRepository), action: presentRepositoryPicker)
                .disabled(!state.canReplaceRepository)
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button(String(localized: .copySHA), action: state.copyCommitObjectID)
                .disabled(state.copyableCommitObjectID == nil)
            Button(String(localized: .copyBranchName), action: state.copyBranchName)
                .disabled(state.copyableBranchName == nil)
        }

        CommandGroup(after: .sidebar) {
            Toggle(String(localized: .repositoryInfo), isOn: $state.isShowingInspector)
        }

        CommandMenu(String(localized: .repositoryMenu)) {
            Button(String(localized: .fetch), action: unavailableAction)
                .disabled(true)
            Button(String(localized: .pull), action: unavailableAction)
                .disabled(true)
            Button(String(localized: .push), action: unavailableAction)
                .disabled(true)

            Divider()

            Button(String(localized: .stageAll), action: stageAll)
                .disabled(!state.canStageAll)
            Button(String(localized: .unstageAll), action: unstageAll)
                .disabled(!state.canUnstageAll)
            Button(String(localized: .commit), action: unavailableAction)
                .disabled(true)
            Button(String(localized: .stash), action: unavailableAction)
                .disabled(true)
        }

        CommandMenu(String(localized: .branchMenu)) {
            Button(String(localized: .newBranch), action: state.beginCreatingBranch)
                .disabled(!state.canBeginCreatingBranch)
            Button(String(localized: .checkout), action: checkoutSelectedReference)
                .disabled(!state.canCheckoutSelectedReference)
            Button(String(localized: .merge), action: unavailableAction)
                .disabled(true)
            Button(String(localized: .rebase), action: unavailableAction)
                .disabled(true)
        }
    }

    private func presentRepositoryPicker() {
        state.isPresentingRepositoryPicker = true
    }

    private func unavailableAction() {
    }

    private func checkoutSelectedReference() {
        Task {
            await state.checkoutSelectedReference()
        }
    }

    private func stageAll() {
        Task {
            await state.stageAll()
        }
    }

    private func unstageAll() {
        Task {
            await state.unstageAll()
        }
    }
}
