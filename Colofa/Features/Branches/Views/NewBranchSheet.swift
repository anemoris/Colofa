////
//  NewBranchSheet.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The one New Branch dialog, whichever entry point opened it.
///
/// It reads the open dialog from the Store rather than being handed one, so every edit — a
/// typed name, Git's answer about it, a refusal — reaches the form that has to show it.
struct NewBranchSheet: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if let draft = state.branchCreation {
            NewBranchForm(draft: draft)
        }
    }
}

/// The dialog itself.
///
/// The start point is read-only: the toolbar opens it on HEAD and History opens it on the
/// selected Commit, and both show exactly where the branch begins rather than letting it be
/// retyped into something else.
private struct NewBranchForm: View {
    @Environment(WorkspaceState.self) private var state
    let draft: BranchCreationDraft

    var body: some View {
        VStack(alignment: .leading) {
            Text(.newBranch)
                .font(.headline)

            LabeledContent(String(localized: .branchStartPoint)) {
                BranchStartPointLabel(startPoint: draft.startPoint)
            }

            TextField(String(localized: .branchName), text: name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("repository.newBranch.name")

            NewBranchNote(draft: draft, validation: state.branchNameValidation)

            Toggle(isOn: checksOutNewBranch) {
                Text(.checkoutNewBranch)
            }
            .accessibilityIdentifier("repository.newBranch.checkout")

            HStack {
                Spacer(minLength: 0)
                Button(.cancel, role: .cancel, action: state.cancelBranchCreation)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repository.newBranch.cancel")
                Button(.createBranch, action: create)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.canCreateBranch)
                    .accessibilityIdentifier("repository.newBranch.create")
            }
        }
        .padding()
        .frame(width: LayoutMetrics.Branch.dialogWidth)
        // Re-asked whenever the typed name changes, so the answer always belongs to what is in
        // the field rather than to whatever was there when the dialog opened.
        .task(id: state.branchNameValidationIdentity) {
            await state.validateBranchName()
        }
    }

    private var name: Binding<String> {
        Binding(
            get: { state.branchCreation?.name ?? "" },
            set: { state.branchCreation?.name = $0 }
        )
    }

    private var checksOutNewBranch: Binding<Bool> {
        Binding(
            get: { state.branchCreation?.checksOutNewBranch ?? true },
            set: { state.branchCreation?.checksOutNewBranch = $0 }
        )
    }

    private func create() {
        Task {
            await state.createBranch()
        }
    }
}

/// Where the branch begins, named the way the pane that chose it names things: a branch by its
/// own name, a Commit by the abbreviation Git itself reported.
private struct BranchStartPointLabel: View {
    let startPoint: BranchStartPoint

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.captionSpacing) {
            Text(verbatim: startPoint.label)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            if !startPoint.summary.isEmpty {
                Text(verbatim: startPoint.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(startPoint.kind))
        .accessibilityValue(Text(verbatim: startPoint.label))
        .accessibilityIdentifier("repository.newBranch.startPoint")
    }
}

/// The one thing standing between the typed name and a created branch: what Git refused last, or
/// what it says about the name as it stands.
private struct NewBranchNote: View {
    let draft: BranchCreationDraft
    let validation: BranchNameValidation

    var body: some View {
        if let failure = draft.failure {
            VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
                RepositoryConfigurationNote(
                    message: failure.message,
                    systemImage: "exclamationmark.triangle",
                    isWarning: true
                )
                .fixedSize(horizontal: false, vertical: true)
                if let details = failure.details, !details.output.isEmpty {
                    ScrollView {
                        Text(verbatim: details.output)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: LayoutMetrics.Branch.maximumFailureOutputHeight)
                }
            }
            .accessibilityIdentifier("repository.newBranch.failure")
        } else if let message = validation.message {
            RepositoryConfigurationNote(
                message: message,
                systemImage: "exclamationmark.triangle",
                isWarning: true
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("repository.newBranch.validation")
        }
    }
}
