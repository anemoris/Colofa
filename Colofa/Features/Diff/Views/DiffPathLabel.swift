////
//  DiffPathLabel.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Names one file of a patch: where it now is, what it was called before, and whatever the caller
/// has to say about its size.
///
/// Shared by a rendered Diff's file header and by the summary of one Colofa refused to render, so
/// a path reads the same whether or not its patch was loaded. The trailing content is a stored
/// view value rather than an escaping builder, because the two callers supply different kinds of
/// figure — counted lines, or the note that there are none to count.
struct DiffPathLabel<Figure: View>: View {
    let path: String
    /// The path before a rename, absent when the file did not move.
    let originalPath: String?
    let figure: Figure

    init(path: String, originalPath: String?, @ViewBuilder figure: () -> Figure) {
        self.path = path
        self.originalPath = originalPath
        self.figure = figure()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.captionSpacing) {
            HStack {
                Text(verbatim: path)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                figure
            }
            if let originalPath {
                Text(.diffRenamedFrom(originalPath))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}
