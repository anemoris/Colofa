////
//  DeleteBranchSheet.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The one Delete Branch confirmation, whichever entry point opened it.
///
/// It reads the pending Delete from the Store rather than being handed one, so a refusal Git gave
/// after the first press reaches the same dialog the user is still looking at.
struct DeleteBranchSheet: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if let deletion = state.branchDeletion {
            DeleteBranchForm(deletion: deletion)
        }
    }
}

/// The dialog itself.
///
/// It says three things in the order they matter: which Branch is going, what removing it costs,
/// and — only when Git's own protection will not carry it — the explicit force that would.
private struct DeleteBranchForm: View {
    @Environment(WorkspaceState.self) private var state
    let deletion: BranchDeletion

    var body: some View {
        VStack(alignment: .leading) {
            Text(.deleteBranch)
                .font(.headline)

            LabeledContent(String(localized: .branch)) {
                Text(verbatim: deletion.branch)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(deletion.branch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("repository.deleteBranch.branch")
            }

            DeleteBranchCostNote(deletion: deletion)

            if deletion.isForceRequired {
                Toggle(isOn: forcesDeletion) {
                    Text(.forceDeleteBranch)
                }
                .accessibilityIdentifier("repository.deleteBranch.force")
            }

            DeleteBranchFailureNote(failure: deletion.failure)

            HStack {
                Spacer(minLength: 0)
                Button(.cancel, role: .cancel, action: state.cancelBranchDeletion)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repository.deleteBranch.cancel")
                // Removing a name Git can restore and dropping History nothing else holds are
                // different promises, so the button says which one pressing it makes.
                Button(
                    deletion.forcesDeletion ? .forceDeleteBranch : .deleteBranch,
                    role: .destructive,
                    action: confirm
                )
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!state.canConfirmBranchDeletion)
                .accessibilityIdentifier("repository.deleteBranch.confirm")
            }
        }
        .padding()
        .frame(width: LayoutMetrics.Branch.dialogWidth)
    }

    private var forcesDeletion: Binding<Bool> {
        Binding(
            get: { state.branchDeletion?.forcesDeletion ?? false },
            set: { state.branchDeletion?.forcesDeletion = $0 }
        )
    }

    private func confirm() {
        Task {
            await state.confirmBranchDeletion()
        }
    }
}

/// What removing this Branch actually costs, said as a number rather than as the word "unmerged".
///
/// A Branch every other Ref already holds loses no Commit at all, and saying so is what keeps an
/// ordinary cleanup from reading like a destructive act. A Branch holding History nothing else
/// reaches loses exactly that much, counted rather than described.
private struct DeleteBranchCostNote: View {
    let deletion: BranchDeletion

    var body: some View {
        RepositoryConfigurationNote(
            message: message,
            systemImage: deletion.isForceRequired ? "exclamationmark.triangle" : "info.circle",
            isWarning: deletion.isForceRequired
        )
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("repository.deleteBranch.cost")
    }

    private var message: LocalizedStringResource {
        guard deletion.survey.holdsUniqueCommits else {
            return .deleteBranchKeepsEveryCommit
        }
        return .deleteBranchLosesCommits(
            deletion.survey.uniqueCommitCount.formatted(.number)
        )
    }
}

/// Git's own words when it refused, kept inside the dialog rather than over it.
private struct DeleteBranchFailureNote: View {
    let failure: BranchDeletionFailure?

    var body: some View {
        if let failure {
            VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
                RepositoryConfigurationNote(
                    message: failure.message,
                    systemImage: "exclamationmark.triangle",
                    isWarning: true
                )
                .fixedSize(horizontal: false, vertical: true)
                if !failure.details.output.isEmpty {
                    ScrollView {
                        Text(verbatim: failure.details.output)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: LayoutMetrics.Branch.maximumFailureOutputHeight)
                }
            }
            .accessibilityIdentifier("repository.deleteBranch.failure")
        }
    }
}
