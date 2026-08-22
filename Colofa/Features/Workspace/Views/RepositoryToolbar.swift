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
            Button(.fetch, systemImage: "arrow.triangle.2.circlepath", action: unavailableAction)
                .labelStyle(.iconOnly)
                .help(String(localized: .fetchHelp))
                .disabled(true)

            Button(.pull, systemImage: "arrow.down", action: unavailableAction)
                .labelStyle(.iconOnly)
                .help(String(localized: .pullHelp))
                .disabled(true)

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
