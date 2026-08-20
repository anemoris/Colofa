////
//  DetailView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct DetailView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        DetailContentView()
            // Keyed on everything that decides which patch belongs here, so a selection that
            // changed, moved between Staged and unstaged, or was reloaded re-reads rather than
            // leaving the previous file's Diff on screen.
            .task(id: state.diffIdentity) {
                await state.loadDiff()
            }
    }
}

private struct DetailContentView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        @Bindable var state = state

        if state.selectedSection == .history {
            HistoryCommitDetailView()
        } else if state.selectedSection == .changes,
                  let selection = state.selectedChange,
                  let change = state.change(for: selection) {
            VStack(spacing: 0) {
                VStack(alignment: .leading) {
                    HStack {
                        RepositoryChangeRow(change: change)
                        Spacer()
                        RepositoryChangeActionButton(
                            change: change,
                            isStaged: selection.isStaged
                        )
                        .accessibilityIdentifier("repository.detail.action")
                    }
                    if change.isConflict {
                        Text(.resolveConflictBeforeStaging)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()

                Divider()

                DiffView(
                    layout: $state.diffLayout,
                    state: state.diff,
                    fileURL: state.diffFileURL,
                    loadAnyway: loadAnyway,
                    reload: reload
                )
            }
        } else {
            ContentUnavailableView {
                Label(.nothingSelected, systemImage: "doc.text.magnifyingglass")
            } description: {
                Text(.nothingSelectedDescription)
            }
            .accessibilityIdentifier("baseline.empty.detail")
        }
    }

    private func loadAnyway() {
        Task {
            await state.loadDiffAnyway()
        }
    }

    private func reload() {
        Task {
            await state.loadDiff()
        }
    }
}
