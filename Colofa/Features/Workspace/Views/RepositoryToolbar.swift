////
//  RepositoryToolbar.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryToolbar: ToolbarContent {
    @Environment(WorkspaceState.self) private var state

    var body: some ToolbarContent {
        @Bindable var state = state

        ToolbarItemGroup {
            FetchToolbarButton()

            PullToolbarButton()

            PushToolbarButton()

            Button(
                .newBranch,
                systemImage: "arrow.triangle.branch",
                action: state.beginCreatingBranch
            )
                .labelStyle(.iconOnly)
                .help(
                    String(
                        localized: state.branchCreationUnavailabilityReason?.message
                            ?? .newBranchHelp
                    )
                )
                .disabled(!state.canBeginCreatingBranch)
                .accessibilityIdentifier("repository.toolbar.newBranch")

            Button(.stash, systemImage: "tray.and.arrow.down", action: unavailableAction)
                .labelStyle(.iconOnly)
                .help(String(localized: .stashHelp))
                .disabled(true)
                .accessibilityIdentifier("repository.toolbar.stash")

            Toggle(isOn: $state.isShowingInspector) {
                Label(.repositoryInfo, systemImage: "info.circle")
            }
            .labelStyle(.iconOnly)
            .toggleStyle(.button)
            .help(String(localized: .repositoryInfoHelp))
            .accessibilityIdentifier("baseline.inspector.toggle")
        }
    }

    private func unavailableAction() {
    }
}

/// Fetch, and the Cancel it becomes while it runs.
///
/// A network command has no duration Colofa can promise, so stopping one stays reachable for as
/// long as it is out there — and it stays in the same place, because that is where the user
/// pressed Fetch. The spinner is the progress; the button around it is the way out, and it goes
/// quiet for the reload that follows, which is a local read and not something to interrupt.
private struct FetchToolbarButton: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        SyncToolbarButton(
            systemImage: "arrow.triangle.2.circlepath",
            count: nil,
            countLabel: nil,
            isRunning: state.fetchProgress != nil,
            isEnabled: state.fetchProgress == nil ? state.canFetch : state.canCancelFetch,
            help: help,
            accessibilityLabel: state.fetchProgress == nil ? .fetch : .cancelFetch,
            accessibilityIdentifier: state.fetchProgress == nil
                ? "repository.toolbar.fetch"
                : "repository.toolbar.cancelFetch",
            progressDescription: state.fetchProgress.map { String(localized: $0.description) },
            action: performAction
        )
    }

    private var help: String {
        if let progress = state.fetchProgress {
            return String(localized: progress.description)
        }
        return String(localized: state.fetchUnavailabilityReason?.message ?? .fetchHelp)
    }

    private func performAction() {
        guard state.fetchProgress == nil else {
            state.cancelFetch()
            return
        }
        Task {
            await state.fetch()
        }
    }
}
