////
//  DiffView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The Diff presentation.
///
/// It renders the state it is handed and offers no way to change the Repository: staging belongs
/// to whatever placed this view, not to the Diff. That is what lets History and a Stash reuse it
/// unchanged and still be read-only, rather than needing a second, quieter copy of it.
struct DiffView: View {
    @Binding var layout: DiffLayout
    let state: DiffLoadState?
    /// Where the file is on disk, when it is there. Absent means there is nothing to open.
    let fileURL: URL?
    let loadAnyway: () -> Void
    let reload: () -> Void

    var body: some View {
        switch state {
        case nil:
            Spacer(minLength: 0)
        case .loading:
            ProgressView(String(localized: .loadingDiff))
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("repository.diff.loading")
        case .loaded(let diff):
            DiffLoadedView(diff: diff, layout: $layout)
        case .confirmationRequired(let summary):
            DiffSummaryView(
                summary: summary,
                title: .diffNotLoadedAutomatically,
                message: .diffNotLoadedAutomaticallyDescription,
                fileURL: nil,
                loadAnyway: loadAnyway
            )
        case .beyondHardLimit(let summary):
            DiffSummaryView(
                summary: summary,
                title: .diffBeyondLimit,
                message: .diffBeyondLimitDescription,
                fileURL: fileURL,
                loadAnyway: nil
            )
        case .conflicted:
            ContentUnavailableView {
                Label(.conflict, systemImage: "exclamationmark.triangle")
            } description: {
                Text(.diffUnavailableForConflict)
            }
            .accessibilityIdentifier("repository.diff.conflicted")
        case .failed(let error):
            DiffFailureView(error: error, reload: reload)
        }
    }
}

private struct DiffLoadedView: View {
    let diff: Diff
    @Binding var layout: DiffLayout

    var body: some View {
        VStack(spacing: 0) {
            DiffLayoutBar(stats: diff.stats, layout: $layout)
            Divider()
            DiffFilesView(files: diff.files, layout: layout)
        }
    }
}

private struct DiffLayoutBar: View {
    let stats: DiffStats
    @Binding var layout: DiffLayout

    var body: some View {
        HStack {
            DiffStatsLabel(stats: stats)
            Spacer()
            Picker(String(localized: .diffLayout), selection: $layout) {
                ForEach(DiffLayout.allCases) { layout in
                    Text(layout.name).tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("repository.diff.layout")
        }
        .padding(.horizontal)
        .padding(.vertical, LayoutMetrics.Diff.bandVerticalPadding)
    }
}

private struct DiffFailureView: View {
    let error: RepositoryOpenError
    let reload: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(.diffLoadFailed, systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            Button(.reloadDiff, action: reload)
        }
        .accessibilityIdentifier("repository.diff.failure")
    }
}
