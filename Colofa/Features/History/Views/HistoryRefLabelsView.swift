////
//  HistoryRefLabelsView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The Refs pointing at one Commit.
///
/// Each carries its own icon and its kind in the accessibility label, so a tag is never told
/// apart from a branch by shape alone.
struct HistoryRefLabelsView: View {
    let labels: [HistoryRefLabel]

    var body: some View {
        // Refs wrap rather than scroll: a Commit can carry more of them than a row is wide, and
        // a row that scrolls sideways inside a list is not something a pointer can reach.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: LayoutMetrics.Diff.contentSpacing) {
                ForEach(labels) { label in
                    HistoryRefLabelView(label: label)
                }
            }
            VStack(alignment: .leading, spacing: LayoutMetrics.Diff.captionSpacing) {
                ForEach(labels) { label in
                    HistoryRefLabelView(label: label)
                }
            }
        }
    }
}

struct HistoryRefLabelView: View {
    let label: HistoryRefLabel

    var body: some View {
        Label {
            Text(verbatim: label.name)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
        } icon: {
            Image(systemName: label.systemImage)
        }
        .font(.caption)
        .padding(.horizontal, LayoutMetrics.Diff.labelSpacing)
        .background(.quaternary, in: .rect(cornerRadius: LayoutMetrics.Diff.labelSpacing))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label.accessibilityName))
        .accessibilityValue(Text(verbatim: label.name))
    }
}
