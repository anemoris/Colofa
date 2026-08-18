////
//  HistoryView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The History of the selected Ref.
///
/// Reading it never changes the Repository: this pane selects Commits and asks for more pages,
/// and nothing here moves HEAD or touches the working tree.
struct HistoryView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            HistoryReferenceBar()
            Divider()
            HistoryContentView()
            if let timeline = state.history?.timeline, !timeline.commits.isEmpty {
                Divider()
                HistoryPageBar(timeline: timeline)
            }
        }
        // Keyed on everything that decides which History belongs here, so a Ref that changed or
        // a Repository that was reloaded re-reads rather than leaving the previous Ref's Commits
        // on screen.
        .task(id: state.historyIdentity) {
            await state.loadHistory()
        }
    }
}

/// Which Ref's History is on screen, and the one action that is about the Ref rather than about
/// a Commit.
private struct HistoryReferenceBar: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        HStack {
            HistoryReferenceLabel(
                reference: state.historyReference,
                head: state.repository?.head
            )
            .accessibilityIdentifier("repository.history.reference")
            Spacer(minLength: 0)
            HistoryScopePicker()
            if state.copyableBranchName != nil {
                Button(.copyBranchName, systemImage: "doc.on.doc", action: state.copyBranchName)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("repository.history.copyBranchName")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, LayoutMetrics.Diff.bandVerticalPadding)
    }
}

/// Which walk History reads. Both are Git's own answers, so choosing one re-asks rather than
/// hiding rows that were already read.
private struct HistoryScopePicker: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        @Bindable var state = state

        Picker(String(localized: .historyScope), selection: $state.historyScope) {
            ForEach(HistoryScope.allCases) { scope in
                Text(scope.name).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityIdentifier("repository.history.scope")
    }
}

private struct HistoryContentView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        switch state.history {
        case nil, .loading?:
            ProgressView(String(localized: .loadingHistory))
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("repository.history.loading")
        case .unborn?:
            ContentUnavailableView {
                Label(.unbornBranch, systemImage: "clock")
            } description: {
                Text(.historyUnbornDescription)
            }
            .accessibilityIdentifier("repository.history.unborn")
        case .failed(let error)?:
            ContentUnavailableView {
                Label(.historyLoadFailed, systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.message)
            } actions: {
                Button(.reloadHistory, action: reload)
            }
            .accessibilityIdentifier("repository.history.failure")
        case .loaded(let timeline)? where timeline.commits.isEmpty:
            ContentUnavailableView {
                Label(.noHistory, systemImage: "clock")
            } description: {
                Text(.noHistoryDescription)
            }
            .accessibilityIdentifier("baseline.empty.history")
        case .loaded(let timeline)?:
            HistoryListView(timeline: timeline)
        }
    }

    private func reload() {
        Task {
            await state.loadHistory()
        }
    }
}

private struct HistoryListView: View {
    @Environment(WorkspaceState.self) private var state
    let timeline: HistoryTimeline

    var body: some View {
        @Bindable var state = state

        List(selection: $state.selectedCommitID) {
            ForEach(timeline.commits) { commit in
                HistoryCommitRow(commit: commit)
                    .tag(commit.objectID)
            }
        }
        .listStyle(.inset)
        .accessibilityIdentifier("repository.history")
    }
}

/// How much History is loaded, and the offer to read more.
///
/// Below the list rather than inside it: a Load More sitting two hundred rows down is only
/// reachable by scrolling past everything the user just asked to see, and the count is the one
/// thing a list of Commits cannot state about itself.
private struct HistoryPageBar: View {
    @Environment(WorkspaceState.self) private var state
    let timeline: HistoryTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
            if let failure = state.historyPageFailure {
                Text(failure.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("repository.history.pageFailure")
            }
            HStack {
                LabeledContent(String(localized: .commits)) {
                    Text(timeline.commits.count, format: .number)
                }
                .accessibilityIdentifier("repository.history.loadedCount")
                Spacer(minLength: 0)
                if timeline.isLoadingMore {
                    ProgressView()
                        .controlSize(.small)
                } else if timeline.hasMore || state.historyPageFailure != nil {
                    Button(.loadMoreHistory, action: loadMore)
                        .accessibilityIdentifier("repository.history.loadMore")
                }
            }
        }
        .font(.callout)
        .padding(.horizontal)
        .padding(.vertical, LayoutMetrics.Diff.bandVerticalPadding)
    }

    private func loadMore() {
        Task {
            await state.loadMoreHistory()
        }
    }
}
