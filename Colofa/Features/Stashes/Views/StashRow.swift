////
//  StashRow.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// One entry in the Stashes list.
struct StashRow: View {
    let stash: Stash

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutMetrics.Diff.captionSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: stash.message)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if stash.includesUntrackedFiles {
                    // Written out rather than left to an icon: whether a Stash carries files Git
                    // was not tracking is a fact about it, and colour or shape alone would not
                    // state it.
                    Label(.stashIncludesUntracked, systemImage: "questionmark.folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: LayoutMetrics.Diff.contentSpacing) {
                Text(verbatim: stash.selector)
                    .font(.system(.caption, design: .monospaced))
                Text(verbatim: stash.abbreviatedObjectID)
                    .font(.system(.caption, design: .monospaced))
                Text(verbatim: stash.authorName)
                    .font(.caption)
                    .lineLimit(1)
                Text(stash.authoredDate, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repository.stash.\(stash.selector)")
    }
}
