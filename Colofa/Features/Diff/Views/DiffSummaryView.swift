////
//  DiffSummaryView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// What a patch Colofa did not render is allowed to say about itself: which files it touches,
/// how many lines Git counted, and where the file is if the user would rather read it elsewhere.
struct DiffSummaryView: View {
    let summary: DiffSummary
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    /// Where the file is on disk, offered only for a patch beyond a hard limit: that is the one
    /// state with nothing else left to do with it.
    let fileURL: URL?
    /// Absent when a hard limit was reached, because there is nothing left to offer.
    let loadAnyway: (() -> Void)?

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutMetrics.Diff.sectionSpacing) {
                VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DiffMeasurementLabel(measurement: summary.measurement)

                VStack(alignment: .leading, spacing: LayoutMetrics.Diff.labelSpacing) {
                    Text(.diffChangedFiles)
                        .font(.headline)
                    ForEach(summary.files) { file in
                        DiffFileSummaryRow(file: file)
                    }
                }

                HStack {
                    if let loadAnyway {
                        Button(.loadDiffAnyway, action: loadAnyway)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("repository.diff.loadAnyway")
                    }
                    if let fileURL {
                        Button(.openInDefaultEditor) {
                            openURL(fileURL)
                        }
                        .accessibilityIdentifier("repository.diff.openInEditor")
                    }
                }

                // A deletion has nothing left on disk to open. Saying so is the point: a refused
                // patch that offered no action at all would leave the counts above looking like
                // everything Colofa was willing to do.
                if fileURL == nil, loadAnyway == nil {
                    Text(.diffPathNotInWorkingTree)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("repository.diff.pathAbsent")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("repository.diff.summary")
    }
}

private struct DiffFileSummaryRow: View {
    let file: DiffFileSummary

    var body: some View {
        DiffPathLabel(
            path: file.newPath,
            originalPath: file.isRenamed ? file.oldPath : nil
        ) {
            // Git counts no lines for binary content, so the row says so rather than showing a
            // pair of zeroes that would read as "nothing changed".
            if let stats = file.stats {
                DiffStatsLabel(stats: stats)
            } else {
                Text(.diffBinaryContent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
