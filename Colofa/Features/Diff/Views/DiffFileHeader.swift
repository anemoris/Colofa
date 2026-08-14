////
//  DiffFileHeader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Names the file a patch describes, stating both paths whenever they differ so a rename is
/// visible in the Diff itself rather than only in the Change that led to it.
struct DiffFileHeader: View {
    let file: DiffFile

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.captionSpacing) {
            DiffPathLabel(
                path: file.displayPath,
                originalPath: file.isRenamed ? file.oldPath : nil
            ) {
                DiffStatsLabel(stats: file.stats)
            }
            if let mode = file.changedMode {
                DiffModeChangeLabel(oldMode: mode.old, newMode: mode.new)
            }
        }
        .padding(.horizontal, LayoutMetrics.Diff.bandHorizontalPadding)
        .padding(.vertical, LayoutMetrics.Diff.bandVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35))
    }
}

private struct DiffModeChangeLabel: View {
    let oldMode: String
    let newMode: String

    var body: some View {
        HStack(spacing: LayoutMetrics.Diff.contentSpacing) {
            Text(.diffModeChanged)
            Text(verbatim: "\(oldMode) → \(newMode)")
                .font(.system(.caption, design: .monospaced))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
