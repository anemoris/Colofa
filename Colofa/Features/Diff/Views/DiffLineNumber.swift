////
//  DiffLineNumber.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// One gutter cell, empty on the side where the line does not exist.
///
/// Hidden from accessibility so VoiceOver reads the code rather than being interrupted by digits,
/// and so copying a Diff yields the code alone.
struct DiffLineNumber: View {
    let number: Int?

    var body: some View {
        Text(verbatim: number.map { $0.formatted(.number.grouping(.never)) } ?? "")
            .font(.system(.caption, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: LayoutMetrics.Diff.lineNumberWidth, alignment: .trailing)
            .accessibilityHidden(true)
    }
}
