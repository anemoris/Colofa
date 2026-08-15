////
//  DiffFilesView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The scrolling body of a rendered patch.
///
/// Each layout gets a `ScrollView` of its own rather than one whose axes are switched underneath
/// it. The two need opposite things from their container — Unified scrolls sideways so a long
/// line stays reachable, Split needs a bounded width so its two panes can each take half — and a
/// scroll view that has already been laid out along one axis does not reliably take up the other.
struct DiffFilesView: View {
    let files: [DiffFile]
    let layout: DiffLayout

    var body: some View {
        switch layout {
        case .unified:
            DiffUnifiedFilesView(files: files)
        case .split:
            DiffSplitFilesView(files: files)
        }
    }
}

/// Scrolls in both directions, with lines at their intrinsic width.
///
/// A bidirectional `ScrollView` centres content smaller than its viewport, so the stack is asked
/// for at least the viewport's size and pinned to its top-leading corner. `GeometryReader` is
/// what supplies that size, since the alternatives available on macOS 14 can only set an exact
/// one and would clip whatever overflows.
private struct DiffUnifiedFilesView: View {
    let files: [DiffFile]

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                DiffFileStack(files: files, layout: .unified)
                    .frame(
                        minWidth: proxy.size.width,
                        minHeight: proxy.size.height,
                        alignment: .topLeading
                    )
            }
            .textSelection(.enabled)
        }
        .accessibilityIdentifier("repository.diff.content")
    }
}

/// Scrolls vertically only, which is what leaves the width bounded for two half-width panes to
/// divide between them. Long lines wrap inside their pane rather than being cut off.
private struct DiffSplitFilesView: View {
    let files: [DiffFile]

    var body: some View {
        ScrollView(.vertical) {
            DiffFileStack(files: files, layout: .split)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .textSelection(.enabled)
        .accessibilityIdentifier("repository.diff.content")
    }
}

private struct DiffFileStack: View {
    let files: [DiffFile]
    let layout: DiffLayout

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(files) { file in
                DiffFileView(file: file, layout: layout)
            }
        }
    }
}
