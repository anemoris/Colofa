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
            // Same reason again: a Push started from this menu must keep its way out when the
            // toolbar is hidden. The title follows the Branch, because publishing one for the
            // first time and sending one to its upstream are different things to agree to.
            if state.isPushing {
                Button(String(localized: .cancelPush), action: state.cancelPush)
                    .disabled(!state.canCancelPush)
            } else {
                Button(
                    String(
                        localized: state.isCurrentBranchUnpublished ? .publish : .push
                    ),
                    action: push
                )
                .disabled(!state.canPush)
            }

            Divider()

            Button(String(localized: .stageAll), action: stageAll)
                .disabled(!state.canStageAll)
            Button(String(localized: .unstageAll), action: unstageAll)
                .disabled(!state.canUnstageAll)
            // Commits the composer's own draft, which is the only Commit there is: the menu is a
            // second way to reach it when the middle column is not where the focus happens to be.
            Button(String(localized: .commit), action: commit)
                .disabled(!state.canCommit)
            Button(String(localized: .stash), action: unavailableAction)
                .disabled(true)
        }

        CommandMenu(String(localized: .branchMenu)) {
            Button(String(localized: .newBranch), action: state.beginCreatingBranch)
                .disabled(!state.canBeginCreatingBranch)
            Button(String(localized: .checkout), action: checkoutSelectedReference)
                .disabled(!state.canCheckoutSelectedReference)
            // Acts on the sidebar's selected Ref, the same one Checkout does, so the menu never
            // deletes a Branch other than the one the window is showing as chosen.
            Button(String(localized: .deleteBranch), action: deleteSelectedBranch)
                .disabled(!state.canDeleteSelectedBranch)
            // Acts on the sidebar's selected Ref, the same one Checkout and Delete Branch do, so
            // the menu never merges a Branch other than the one the window shows as chosen.
            Button(String(localized: .merge), action: state.beginMergingSelectedReference)
                .disabled(!state.canMergeSelectedReference)
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

    private func push() {
        Task {
            await state.beginPush()
        }
    }

    private func commit() {
        Task {
            await state.commit()
        }
    }

    private func checkoutSelectedReference() {
        Task {
            await state.checkoutSelectedReference()
        }
    }

    private func deleteSelectedBranch() {
        Task {
            await state.beginDeletingSelectedBranch()
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
