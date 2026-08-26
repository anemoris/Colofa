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
            // The toolbar is where a running Fetch is normally stopped, but the toolbar is
            // something macOS lets the user hide — and hiding it would otherwise leave a Fetch
            // started from this menu with no way out at all. So the menu carries the same
            // Cancel rather than only greying Fetch out. It disables itself once the Fetch is
            // done with the remote and only its reload is left.
            if state.isFetching {
                Button(String(localized: .cancelFetch), action: state.cancelFetch)
                    .disabled(!state.canCancelFetch)
            } else {
                Button(String(localized: .fetch), action: fetch)
                    .disabled(!state.canFetch)
            }
            Button(String(localized: .fetchTags), action: fetchTags)
                .disabled(!state.canFetchTags)
            // Same reason the menu carries a Cancel for Fetch: the toolbar is something macOS
            // lets the user hide, and hiding it must not leave a Pull started here with no way
            // out. It disables itself once the Pull is past the half that can be stopped.
            if state.isPulling {
                Button(String(localized: .cancelPull), action: state.cancelPull)
                    .disabled(!state.canCancelPull)
            } else {
                Button(String(localized: .pull), action: pull)
                    .disabled(!state.canPull)
            }
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

    private func fetch() {
        Task {
            await state.fetch()
        }
    }

    private func fetchTags() {
        Task {
            await state.fetchTags()
        }
    }

    private func pull() {
        Task {
            await state.pull()
        }
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
