////
//  DiffHunkView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// One Hunk in the chosen layout.
///
/// The rows are the lazy stack's own children rather than being wrapped in a container, so a
/// Hunk that covers a rewritten file still only builds the rows on screen.
struct DiffHunkView: View {
    let hunk: DiffHunk
    let layout: DiffLayout

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            DiffHunkHeaderRow(hunk: hunk)
            switch layout {
            case .unified:
                ForEach(hunk.lines) { line in
                    DiffUnifiedRow(line: line)
                }
            case .split:
                ForEach(hunk.splitRows) { row in
                    DiffSplitRowView(row: row)
                }
            }
        }
        .accessibilityIdentifier("repository.diff.hunk.\(layout.rawValue)")
    }
}
