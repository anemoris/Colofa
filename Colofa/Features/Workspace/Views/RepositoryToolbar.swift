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

            Button(.push, systemImage: "arrow.up", action: unavailableAction)
                .labelStyle(.iconOnly)
                .help(String(localized: .pushHelp))
                .disabled(true)

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
        if let progress = state.fetchProgress {
            Button(action: state.cancelFetch) {
                ProgressView()
                    .controlSize(.small)
            }
            .disabled(!state.canCancelFetch)
            .help(String(localized: progress.description))
            .accessibilityLabel(Text(.cancelFetch))
            .accessibilityValue(Text(progress.description))
            .accessibilityIdentifier("repository.toolbar.cancelFetch")
        } else {
            Button(.fetch, systemImage: "arrow.triangle.2.circlepath", action: fetch)
                .labelStyle(.iconOnly)
                .help(
                    String(localized: state.fetchUnavailabilityReason?.message ?? .fetchHelp)
                )
                .disabled(!state.canFetch)
                .accessibilityIdentifier("repository.toolbar.fetch")
        }
    }

    private func fetch() {
        Task {
            await state.fetch()
        }
    }
}
