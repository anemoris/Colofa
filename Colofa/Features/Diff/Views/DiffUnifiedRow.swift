////
//  DiffUnifiedRow.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct DiffUnifiedRow: View {
    let line: DiffLine

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            DiffLineNumber(number: line.oldNumber)
            DiffLineNumber(number: line.newNumber)
            DiffLineText(line: line, wraps: false)
            Spacer(minLength: 0)
        }
        .padding(.vertical, LayoutMetrics.Diff.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(line.tint.opacity(LayoutMetrics.Diff.rowBackgroundOpacity))
    }
}

extension DiffLine {
    var tint: Color {
        switch kind {
        case .addition: .green
        case .deletion: .red
        case .context, .noNewlineMarker: .clear
        }
    }
}
