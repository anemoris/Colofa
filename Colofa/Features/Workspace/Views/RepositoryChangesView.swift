////
//  RepositoryChangesView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryChangesView: View {
    @Environment(WorkspaceState.self) private var state
    let repository: RepositorySnapshot

    var body: some View {
        @Bindable var state = state
        let isClean = repository.stagedChanges.isEmpty && repository.unstagedChanges.isEmpty

        VStack(spacing: 0) {
            if let operation = repository.operation {
                RepositoryOperationBanner(operation: operation)
                Divider()
            }

            if isClean {
                ContentUnavailableView {
                    Label(.noChanges, systemImage: "checkmark.circle")
                } description: {
                    Text(.noChangesDescription)
                } actions: {
                    if state.canAmend {
                        Button(.amendCommit, action: amend)
                            .accessibilityIdentifier("repository.commit.expandAmend")
                    }
                }
                .accessibilityIdentifier("baseline.empty.changes")
            } else {
                List(selection: $state.selectedChange) {
                    Section {
                        ForEach(repository.stagedChanges, id: \.stagedListID) { change in
                            RepositoryChangeListRow(change: change, isStaged: true)
                                .tag(RepositoryChangeSelection(path: change.path, isStaged: true))
                        }
                    } header: {
                        LabeledContent(String(localized: .stagedChanges)) {
                            Text(repository.stagedChanges.count, format: .number)
                            Button(.unstageAll, action: unstageAll)
                                .disabled(!state.canUnstageAll)
                                .accessibilityIdentifier("repository.unstageAll")
                        }
                    }

                    Section {
                        ForEach(repository.unstagedChanges, id: \.unstagedListID) { change in
                            RepositoryChangeListRow(change: change, isStaged: false)
                                .tag(RepositoryChangeSelection(path: change.path, isStaged: false))
                        }
                    } header: {
                        LabeledContent(String(localized: .changes)) {
                            Text(repository.unstagedChanges.count, format: .number)
                            Button(.stageAll, action: stageAll)
                                .disabled(!state.canStageAll)
                                .accessibilityIdentifier("repository.stageAll")
                        }
                    }
                }
                .listStyle(.inset)
                .accessibilityIdentifier("repository.changes")
            }

            if !isClean || state.commitDraft.isAmending {
                Divider()
                CommitComposerView(repository: repository)
            }
        }
    }

    private func stageAll() {
        Task {
            await state.stageAll()
        }
    }

    private func unstageAll() {
        Task {
            await state.unstageAll()
        }
    }

    private func amend() {
        state.setAmending(true)
    }
}

private extension RepositoryChange {
    var stagedListID: String { "staged.\(id)" }
    var unstagedListID: String { "unstaged.\(id)" }
}
