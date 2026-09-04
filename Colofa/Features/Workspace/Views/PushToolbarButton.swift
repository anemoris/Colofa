////
//  PushToolbarButton.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Push, the count of what is waiting to go up, the Publish it becomes for a Branch nobody has
/// pushed yet, and the Cancel all of them become while they are out at the remote.
///
/// The two names are not decoration. A Branch with no upstream is not being sent anywhere yet — it
/// is being created on a remote for the first time, and calling that Push would hide the one
/// decision it involves. The way out stays in the place the user pressed, for as long as anything
/// is out there.
///
/// Publish never carries a count: a Branch with no upstream has nothing counted against it, which
/// is a different statement from being level. The `↑n` badge is `DESIGN.md` §「关键 IA 决策」⑤,
/// and `SyncToolbarButton` holds the identity rule that keeps the toolbar from splitting — this
/// button needs it most, because it can change what it offers without any command running, when
/// `isCurrentBranchUnpublished` flips after a reload.
struct PushToolbarButton: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        SyncToolbarButton(
            systemImage: isPublishing ? "arrow.up.to.line" : "arrow.up",
            count: state.pushAheadCount,
            countLabel: .ahead,
            isRunning: state.pushProgress != nil,
            isEnabled: state.pushProgress == nil ? state.canPush : state.canCancelPush,
            help: help,
            accessibilityLabel: accessibilityLabel,
            accessibilityIdentifier: accessibilityIdentifier,
            progressDescription: state.pushProgress.map { String(localized: $0.description) },
            action: performAction
        )
    }

    private var isPublishing: Bool {
        state.pushProgress == nil && state.isCurrentBranchUnpublished
    }

    private var help: String {
        if let progress = state.pushProgress {
            return String(localized: progress.description)
        }
        return String(
            localized: state.pushUnavailabilityReason?.message
                ?? (isPublishing ? .publishHelp : .pushHelp)
        )
    }

    private var accessibilityLabel: LocalizedStringResource {
        if state.pushProgress != nil {
            return .cancelPush
        }
        return isPublishing ? .publish : .push
    }

    private var accessibilityIdentifier: String {
        if state.pushProgress != nil {
            return "repository.toolbar.cancelPush"
        }
        return isPublishing ? "repository.toolbar.publish" : "repository.toolbar.push"
    }

    private func performAction() {
        guard state.pushProgress == nil else {
            state.cancelPush()
            return
        }
        Task {
            await state.beginPush()
        }
    }
}
