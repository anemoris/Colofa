////
//  HistoryCommitRow.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// One Commit in the History list.
struct HistoryCommitRow: View {
    let commit: HistoryCommit

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.captionSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: commit.summary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if commit.isMerge {
                    // Written out rather than left to an icon: a merge is a fact about the
                    // Commit, and colour or shape alone would not state it.
                    Label(.commitMerge, systemImage: "arrow.triangle.merge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: LayoutMetrics.Diff.contentSpacing) {
                Text(verbatim: commit.abbreviatedObjectID)
                    .font(.system(.caption, design: .monospaced))
                Text(verbatim: commit.authorName)
                    .font(.caption)
                    .lineLimit(1)
                Text(commit.authoredDate, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)

            if !commit.refLabels.isEmpty {
                HistoryRefLabelsView(labels: commit.refLabels)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repository.history.commit.\(commit.objectID)")
    }
}
