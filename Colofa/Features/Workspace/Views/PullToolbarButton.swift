////
//  PullToolbarButton.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Pull, and the Cancel it becomes while it is contacting the remote.
///
/// The way out stays in the place the user pressed Pull, and only for as long as it is honest:
/// the Fetch half has no duration Colofa can promise, while the fast-forward after it is a short
/// local command that must not stop halfway. So the spinner stays for both halves and the Cancel
/// behind it goes away with the first.
struct PullToolbarButton: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if let progress = state.pullProgress {
            Button(action: state.cancelPull) {
                ProgressView()
                    .controlSize(.small)
            }
            .disabled(!state.canCancelPull)
            .help(String(localized: progress.description))
            .accessibilityLabel(Text(.cancelPull))
            .accessibilityValue(Text(progress.description))
            .accessibilityIdentifier("repository.toolbar.cancelPull")
        } else {
            Button(.pull, systemImage: "arrow.down", action: pull)
                .labelStyle(.iconOnly)
                .help(String(localized: state.pullUnavailabilityReason?.message ?? .pullHelp))
                .disabled(!state.canPull)
                .accessibilityIdentifier("repository.toolbar.pull")
        }
    }

    private func pull() {
        Task {
            await state.pull()
        }
    }
}
