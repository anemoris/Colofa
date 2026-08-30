////
//  PushToolbarButton.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Push, the Publish it becomes for a Branch nobody has pushed yet, and the Cancel both become
/// while they are out at the remote.
///
/// The two names are not decoration. A Branch with no upstream is not being sent anywhere yet — it
/// is being created on a remote for the first time, and calling that Push would hide the one
/// decision it involves. The way out stays in the place the user pressed, for as long as anything
/// is out there.
struct PushToolbarButton: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if let progress = state.pushProgress {
            Button(action: state.cancelPush) {
                ProgressView()
                    .controlSize(.small)
            }
            .disabled(!state.canCancelPush)
            .help(String(localized: progress.description))
            .accessibilityLabel(Text(.cancelPush))
            .accessibilityValue(Text(progress.description))
            .accessibilityIdentifier("repository.toolbar.cancelPush")
        } else if state.isCurrentBranchUnpublished {
            Button(.publish, systemImage: "arrow.up.to.line", action: push)
                .labelStyle(.iconOnly)
                .help(String(localized: state.pushUnavailabilityReason?.message ?? .publishHelp))
                .disabled(!state.canPush)
                .accessibilityIdentifier("repository.toolbar.publish")
        } else {
            Button(.push, systemImage: "arrow.up", action: push)
                .labelStyle(.iconOnly)
                .help(String(localized: state.pushUnavailabilityReason?.message ?? .pushHelp))
                .disabled(!state.canPush)
                .accessibilityIdentifier("repository.toolbar.push")
        }
    }

    private func push() {
        Task {
            await state.beginPush()
        }
    }
}
