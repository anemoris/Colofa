////
//  CommitComposerView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import SwiftUI

/// The Commit composer, directly below the Staged Changes it commits.
///
/// A clean working tree expands it only after the user chooses Amend.
struct CommitComposerView: View {
    @Environment(WorkspaceState.self) private var state
    let repository: RepositorySnapshot

    var body: some View {
        @Bindable var state = state

        VStack(alignment: .leading) {
            CommitComposerHeader(repository: repository)

            // Both fields close while the Commit runs: the message Git was given is already
            // fixed, and the composer is cleared afterwards, so text typed now would be lost
            // twice over.
            TextField(String(localized: .commitSummary), text: $state.commitDraft.summary)
                .textFieldStyle(.roundedBorder)
                .disabled(state.isCommitting)
                .accessibilityIdentifier("repository.commit.summary")

            if state.commitDraft.exceedsRecommendedSummaryLength {
                RepositoryConfigurationNote(
                    message: .commitSummaryLengthGuidance,
                    systemImage: "exclamationmark.triangle",
                    isWarning: true
                )
                .accessibilityIdentifier("repository.commit.summaryGuidance")
            }

            TextField(
                String(localized: .commitDescription),
                text: $state.commitDraft.body,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...5)
            .disabled(state.isCommitting)
            .accessibilityIdentifier("repository.commit.description")

            if state.amendReformatsMessage {
                RepositoryConfigurationNote(
                    message: .amendReformatsMessageGuidance,
                    systemImage: "exclamationmark.triangle",
                    isWarning: true
                )
                .accessibilityIdentifier("repository.commit.reformatGuidance")
            }

            HStack {
                Toggle(isOn: amend) {
                    Text(.commitAmend)
                }
                .disabled(!state.canAmend)
                .accessibilityIdentifier("repository.commit.amend")

                Spacer()

                Button(
                    state.commitDraft.isAmending ? .amendCommit : .commit,
                    action: commit
                )
                .buttonStyle(.borderedProminent)
                .disabled(!state.canCommit)
                .help(state.commitUnavailabilityReason?.message ?? .commitHelp)
                .accessibilityIdentifier("repository.commit.action")
            }

            if let reason = state.commitUnavailabilityReason, !reason.isTransient {
                Text(reason.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("repository.commit.unavailableReason")
            }
        }
        .padding()
        .confirmationDialog(
            Text(.amendPublishedCommitTitle),
            isPresented: $state.isConfirmingHistoryRewrite,
            titleVisibility: .visible
        ) {
            Button(.amendPublishedCommitConfirm, role: .destructive, action: confirmAmend)
            Button(.cancel, role: .cancel, action: cancelAmend)
        } message: {
            Text(.amendPublishedCommitMessage)
        }
    }

    private var amend: Binding<Bool> {
        Binding(
            get: { state.commitDraft.isAmending },
            set: { isAmending in state.setAmending(isAmending) }
        )
    }

    private func commit() {
        Task {
            await state.commit()
        }
    }

    private func confirmAmend() {
        Task {
            await state.confirmHistoryRewrite()
        }
    }

    private func cancelAmend() {
        state.cancelHistoryRewrite()
    }
}
