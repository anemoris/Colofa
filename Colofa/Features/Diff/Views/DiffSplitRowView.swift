////
//  DiffSplitRowView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// One Split row: what the change replaced beside what it wrote.
///
/// Both panes take half the width, so a side with no counterpart stays visibly empty rather than
/// letting the other side spread across the row and read as unchanged.
struct DiffSplitRowView: View {
    let row: DiffSplitRow

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            DiffSplitPane(line: row.old, isOldSide: true)
            Divider()
            DiffSplitPane(line: row.new, isOldSide: false)
        }
    }
}

private struct DiffSplitPane: View {
    let line: DiffLine?
    let isOldSide: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            DiffLineNumber(number: isOldSide ? line?.oldNumber : line?.newNumber)
            if let line {
                DiffLineText(line: line, wraps: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, LayoutMetrics.Diff.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
    }

    /// An absent side is shaded as unavailable rather than left blank, which is what tells a
    /// reviewer the replacement was unbalanced instead of merely short.
    private var background: Color {
        guard let line else {
            return Color.secondary.opacity(LayoutMetrics.Diff.rowBackgroundOpacity / 2)
        }
        return line.tint.opacity(LayoutMetrics.Diff.rowBackgroundOpacity)
    }
}
