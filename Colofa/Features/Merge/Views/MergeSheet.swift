////
//  MergeSheet.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The one Merge confirmation, whichever entry point opened it.
///
/// It reads the pending Merge from the Store rather than being handed one, so a Repository read
/// again underneath it reaches the same dialog the user is still looking at.
struct MergeSheet: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if let draft = state.mergeDraft {
            MergeForm(draft: draft)
        }
    }
}

/// The dialog itself, which says the direction first and the policy second.
///
/// Direction is what a Merge is most easily got backwards, so both Branches are named in full
/// before anything is chosen. The policy below them is the only option there is: everything else
/// Git can be told about a merge is deliberately absent.
private struct MergeForm: View {
    @Environment(WorkspaceState.self) private var state
    let draft: MergeDraft

    var body: some View {
        VStack(alignment: .leading) {
            Text(.merge)
                .font(.headline)

            MergeDirectionRow(
                label: .mergeSourceBranch,
                name: draft.source.name,
                accessibilityIdentifier: "repository.merge.source"
            )
            MergeDirectionRow(
                label: .mergeTargetBranch,
                name: draft.target,
                accessibilityIdentifier: "repository.merge.target"
            )

            Picker(selection: strategy) {
                ForEach(MergeStrategy.allCases) { strategy in
                    Text(strategy.title)
                        .tag(strategy)
                }
            } label: {
                Text(.mergeStrategy)
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("repository.merge.strategy")

            RepositoryConfigurationNote(
                message: draft.strategy.explanation,
                systemImage: "info.circle",
                isWarning: false
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("repository.merge.strategyDescription")

            HStack {
                Spacer(minLength: 0)
                Button(.cancel, role: .cancel, action: state.cancelMerge)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repository.merge.cancel")
                Button(.merge, action: confirm)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.canConfirmMerge)
                    .accessibilityIdentifier("repository.merge.confirm")
            }
        }
        .padding()
        .frame(width: LayoutMetrics.Merge.dialogWidth)
    }

    /// The chosen policy, written straight back to the Store's Draft.
    ///
    /// Built by hand rather than with `Binding($state.mergeDraft)`: SwiftUI's optional-Binding
    /// unwrap force-unwraps on every read, and the Store empties `mergeDraft` while the sheet is
    /// still on screen dismissing, so the dialog's last read after Confirm or Cancel would trap.
    /// The fallback to the Draft this View was handed is what that last read returns instead.
    private var strategy: Binding<MergeStrategy> {
        Binding(
            get: { state.mergeDraft?.strategy ?? draft.strategy },
            set: { state.mergeDraft?.strategy = $0 }
        )
    }

    private func confirm() {
        Task {
            await state.confirmMerge()
        }
    }
}

/// One end of the merge, named the way every other Ref in the app is: monospaced, selectable, and
/// truncated in the middle so a long path-shaped branch name keeps both of its ends.
private struct MergeDirectionRow: View {
    let label: LocalizedStringResource
    let name: String
    let accessibilityIdentifier: String

    var body: some View {
        LabeledContent(String(localized: label)) {
            Text(verbatim: name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}
