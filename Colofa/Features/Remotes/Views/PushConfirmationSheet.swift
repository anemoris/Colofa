////
//  PushConfirmationSheet.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The confirmation a Push opens: which Branch is going where, and the one option that would let
/// it replace what is already there.
///
/// It is deliberately small. The only thing it has to establish is that the destination the user
/// is about to write to is the destination they expected — Git resolves that out of configuration
/// nobody normally reads, and this is where it becomes visible.
struct PushConfirmationSheet: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if case .confirmation(let confirmation) = state.pushDialog {
            PushConfirmationForm(confirmation: confirmation)
        }
    }
}

private struct PushConfirmationForm: View {
    @Environment(WorkspaceState.self) private var state
    let confirmation: PushConfirmation

    var body: some View {
        VStack(alignment: .leading) {
            Text(.push)
                .font(.headline)

            LabeledContent(String(localized: .branch)) {
                PushRefLabel(name: confirmation.branch)
                    .accessibilityIdentifier("repository.push.branch")
            }
            LabeledContent(String(localized: .upstream)) {
                PushRefLabel(name: confirmation.target.upstream)
                    .accessibilityIdentifier("repository.push.target")
            }
            // The upstream names a remote; this is the address that name resolves to. Both are
            // shown because only the second one is where the Push actually lands, and Git resolves
            // it out of configuration the user has no other reason to have read.
            LabeledContent(String(localized: .pushDestination)) {
                PushRefLabel(name: confirmation.destination.display)
                    .accessibilityIdentifier("repository.push.destination")
            }

            Toggle(isOn: forcesWithLease) {
                Text(.forcePushWithLease)
            }
            .disabled(!confirmation.canForceWithLease)
            .accessibilityIdentifier("repository.push.forceWithLease")

            PushForceNote(confirmation: confirmation)

            HStack {
                Spacer(minLength: 0)
                Button(.cancel, role: .cancel, action: state.cancelPushConfirmation)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repository.push.cancel")
                // The button says which of the two things it does, and carries the role that
                // makes the system render and announce a destructive one as destructive. Ticking
                // the box changes what pressing this means, so it must change what it reads as.
                Button(
                    confirmation.forcesWithLease ? .forcePush : .push,
                    role: confirmation.forcesWithLease ? .destructive : nil,
                    action: confirm
                )
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!state.canPush)
                .accessibilityIdentifier("repository.push.confirm")
            }
        }
        .padding()
        .frame(width: LayoutMetrics.Remote.pushDialogWidth)
    }

    private var forcesWithLease: Binding<Bool> {
        Binding(
            get: { state.pushDialog?.confirmation?.forcesWithLease ?? false },
            set: { state.pushDialog?.confirmation?.forcesWithLease = $0 }
        )
    }

    private func confirm() {
        Task {
            await state.confirmPush()
        }
    }
}

/// What ticking the box actually means, or why it cannot be ticked at all.
///
/// A Force Push with Lease is the one ordinary action that can destroy somebody else's work, so
/// what protects them is spelled out rather than implied by the word "lease".
private struct PushForceNote: View {
    let confirmation: PushConfirmation

    var body: some View {
        if !confirmation.canForceWithLease {
            RepositoryConfigurationNote(
                message: .forcePushUnavailableNoLease,
                systemImage: "info.circle",
                isWarning: false
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("repository.push.forceNote")
        } else if confirmation.forcesWithLease {
            RepositoryConfigurationNote(
                message: .forcePushWithLeaseDescription(confirmation.target.upstream),
                systemImage: "exclamationmark.triangle",
                isWarning: true
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("repository.push.forceNote")
        }
    }
}

/// A Ref shown the way every other Ref in Colofa is: monospaced, whole, and truncated in the
/// middle when it cannot fit, so the two ends that identify it stay readable.
///
/// Truncation is a layout compromise this dialog cannot afford on its own, because the exact
/// destination is the one thing it exists to establish. So the untruncated name stays reachable
/// two ways that cost the layout nothing: a tooltip, and selectable text the user can copy and
/// compare. VoiceOver reads the whole value regardless of where the glyphs stop.
private struct PushRefLabel: View {
    let name: String

    var body: some View {
        Text(verbatim: name)
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .help(name)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
