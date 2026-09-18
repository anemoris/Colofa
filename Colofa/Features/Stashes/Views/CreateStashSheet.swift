////
//  CreateStashSheet.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The one Stash sheet, whichever entry point opened it.
///
/// It reads the open sheet from the Store rather than being handed one, so every edit — a typed
/// message, an option, a refusal Git gave — reaches the form that has to show it.
struct CreateStashSheet: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if let draft = state.stashCreation {
            CreateStashForm(draft: draft)
        }
    }
}

/// The sheet itself: what the entry will be called, and the two exceptions to what Git saves by
/// default.
///
/// Both options start off and are stated as what they add rather than as what they prevent, so
/// leaving them alone is the ordinary Stash the user already knows. Ignored files get a line of
/// their own precisely because they are the one thing neither option reaches: a user who wanted
/// build output or a secret kept out should read that here rather than find it out afterwards.
private struct CreateStashForm: View {
    @Environment(WorkspaceState.self) private var state
    let draft: StashCreationDraft

    var body: some View {
        VStack(alignment: .leading) {
            Text(.stash)
                .font(.headline)

            // The message and both options close while the Stash runs: Git was handed a copy of
            // them when it started, and the draft is dropped once it lands, so an edit made now
            // would neither reach the command nor survive it.
            TextField(String(localized: .stashMessage), text: message, prompt: Text(.optional))
                .textFieldStyle(.roundedBorder)
                .disabled(state.isPerformingMutation)
                .accessibilityIdentifier("repository.stash.message")

            Toggle(isOn: keepsStagedChanges) {
                Text(.keepStagedChanges)
            }
            .disabled(state.isPerformingMutation)
            .accessibilityIdentifier("repository.stash.keepStaged")

            Toggle(isOn: includesUntrackedFiles) {
                Text(.includeUntrackedFiles)
            }
            .disabled(state.isPerformingMutation)
            .accessibilityIdentifier("repository.stash.includeUntracked")

            Text(.stashIgnoredFilesNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("repository.stash.ignoredNote")

            CreateStashNote(draft: draft, refusal: state.stashCreationRefusal)

            HStack {
                Spacer(minLength: 0)
                Button(.cancel, role: .cancel, action: state.cancelStashCreation)
                    .keyboardShortcut(.cancelAction)
                    .disabled(state.isPerformingMutation)
                    .accessibilityIdentifier("repository.stash.cancel")
                Button(.stash, action: create)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.canCreateStash)
                    .accessibilityIdentifier("repository.stash.confirm")
            }
        }
        .padding()
        .frame(width: LayoutMetrics.Stash.dialogWidth)
        // The Store refuses the cancel too; this keeps the sheet from leaving the screen while
        // the Store still holds it open.
        .interactiveDismissDisabled(state.isPerformingMutation)
    }

    /// Written straight back to the Store's draft.
    ///
    /// Built by hand rather than with `Binding($state.stashCreation)`: SwiftUI's optional-Binding
    /// unwrap force-unwraps on every read, and the Store empties `stashCreation` while the sheet
    /// is still on screen dismissing, so the sheet's last read after Stash or Cancel would trap.
    /// The fallback to the draft this View was handed is what that last read returns instead.
    private var message: Binding<String> {
        Binding(
            get: { state.stashCreation?.message ?? draft.message },
            set: { state.stashCreation?.message = $0 }
        )
    }

    private var keepsStagedChanges: Binding<Bool> {
        Binding(
            get: { state.stashCreation?.keepsStagedChanges ?? draft.keepsStagedChanges },
            set: { state.stashCreation?.keepsStagedChanges = $0 }
        )
    }

    private var includesUntrackedFiles: Binding<Bool> {
        Binding(
            get: { state.stashCreation?.includesUntrackedFiles ?? draft.includesUntrackedFiles },
            set: { state.stashCreation?.includesUntrackedFiles = $0 }
        )
    }

    private func create() {
        Task {
            await state.createStash()
        }
    }
}

/// The one thing standing between the sheet and a saved Stash: what Git refused last, or what the
/// options as they stand would leave unsaved.
private struct CreateStashNote: View {
    let draft: StashCreationDraft
    let refusal: StashCreationUnavailabilityReason?

    var body: some View {
        if let failure = draft.failure {
            VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
                RepositoryConfigurationNote(
                    message: .stashFailedDescription,
                    systemImage: "exclamationmark.triangle",
                    isWarning: true
                )
                .fixedSize(horizontal: false, vertical: true)
                if !failure.output.isEmpty {
                    ScrollView {
                        Text(verbatim: failure.output)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: LayoutMetrics.Stash.maximumFailureOutputHeight)
                }
            }
            .accessibilityIdentifier("repository.stash.failure")
        } else if let refusal {
            RepositoryConfigurationNote(
                message: refusal.message,
                systemImage: "exclamationmark.triangle",
                isWarning: true
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("repository.stash.refusal")
        }
    }
}
