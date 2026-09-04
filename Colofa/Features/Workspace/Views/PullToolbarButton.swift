////
//  PullToolbarButton.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Pull, the count of what is waiting to come down, and the Cancel it becomes while it is
/// contacting the remote.
///
/// The way out stays in the place the user pressed Pull, and only for as long as it is honest:
/// the Fetch half has no duration Colofa can promise, while the fast-forward after it is a short
/// local command that must not stop halfway. So the spinner stays for both halves and the Cancel
/// behind it goes away with the first.
///
/// The `↓n` badge is `DESIGN.md` §「关键 IA 决策」⑤: the number sits on the button that acts on
/// it. `SyncToolbarButton` holds the identity rule that keeps the toolbar from splitting.
struct PullToolbarButton: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        SyncToolbarButton(
            systemImage: "arrow.down",
            count: state.pullBehindCount,
            countLabel: .behind,
            isRunning: state.pullProgress != nil,
            isEnabled: state.pullProgress == nil ? state.canPull : state.canCancelPull,
            help: help,
            accessibilityLabel: state.pullProgress == nil ? .pull : .cancelPull,
            accessibilityIdentifier: state.pullProgress == nil
                ? "repository.toolbar.pull"
                : "repository.toolbar.cancelPull",
            progressDescription: state.pullProgress.map { String(localized: $0.description) },
            action: performAction
        )
    }

    private var help: String {
        if let progress = state.pullProgress {
            return String(localized: progress.description)
        }
        return String(localized: state.pullUnavailabilityReason?.message ?? .pullHelp)
    }

    private func performAction() {
        guard state.pullProgress == nil else {
            state.cancelPull()
            return
        }
        Task {
            await state.pull()
        }
    }
}
