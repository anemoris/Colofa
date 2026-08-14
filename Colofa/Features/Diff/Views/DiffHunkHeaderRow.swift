////
//  DiffHunkHeaderRow.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The ranges Git states for a Hunk, kept verbatim: they are the same text a reviewer would read
/// in a patch file, and translating them would make the two disagree.
struct DiffHunkHeaderRow: View {
    let hunk: DiffHunk

    var body: some View {
        HStack(spacing: LayoutMetrics.Diff.contentSpacing) {
            Text(verbatim: hunk.rangeDescription)
                .foregroundStyle(.secondary)
            if !hunk.heading.isEmpty {
                Text(verbatim: hunk.heading)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.vertical, LayoutMetrics.Diff.hunkHeaderVerticalPadding)
        .padding(.horizontal, LayoutMetrics.Diff.bandHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
    }
}
