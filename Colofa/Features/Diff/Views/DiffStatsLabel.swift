////
//  DiffStatsLabel.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// `+18 −4`, with the signs carrying the meaning so the counts stay readable without colour.
struct DiffStatsLabel: View {
    let stats: DiffStats

    var body: some View {
        HStack(spacing: LayoutMetrics.Diff.contentSpacing) {
            // The sign is written into the text rather than left to a signed format style, which
            // would render an unchanged side as "+0".
            Text(verbatim: "+\(stats.additions.formatted(.number))")
                .foregroundStyle(.green)
                .accessibilityLabel(Text(.additions))
                .accessibilityValue(Text(stats.additions, format: .number))
            Text(verbatim: "−\(stats.deletions.formatted(.number))")
                .foregroundStyle(.red)
                .accessibilityLabel(Text(.deletions))
                .accessibilityValue(Text(stats.deletions, format: .number))
        }
        .font(.system(.caption, design: .monospaced))
        .monospacedDigit()
    }
}
