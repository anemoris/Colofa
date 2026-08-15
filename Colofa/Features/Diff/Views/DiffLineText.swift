////
//  DiffLineText.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The marker and content of one line.
///
/// The marker is a character rather than only a colour, so an addition stays distinguishable from
/// a deletion under Differentiate Without Color.
struct DiffLineText: View {
    let line: DiffLine
    /// Unified scrolls sideways and must not wrap; Split divides the width between two panes, so
    /// wrapping is what keeps a long line visible instead of cutting it off.
    let wraps: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(verbatim: marker)
                .frame(width: LayoutMetrics.Diff.markerWidth, alignment: .leading)
                .accessibilityHidden(true)

            if line.kind == .noNewlineMarker {
                Text(.diffNoNewlineAtEndOfFile)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text(verbatim: line.text)
                    .lineLimit(wraps ? nil : 1)
                    .fixedSize(horizontal: !wraps, vertical: false)
            }
        }
        .font(.system(.callout, design: .monospaced))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var marker: String {
        switch line.kind {
        case .addition: "+"
        case .deletion: "−"
        case .context: " "
        case .noNewlineMarker: "\\"
        }
    }

    /// Only a changed line is named. Context and the no-newline note read as themselves.
    private var accessibilityLabel: Text {
        switch line.kind {
        case .addition: Text(.additions)
        case .deletion: Text(.deletions)
        case .context: Text(verbatim: "")
        case .noNewlineMarker: Text(.diffNoNewlineAtEndOfFile)
        }
    }

    private var accessibilityValue: Text {
        line.kind == .noNewlineMarker ? Text(verbatim: "") : Text(verbatim: line.text)
    }
}
