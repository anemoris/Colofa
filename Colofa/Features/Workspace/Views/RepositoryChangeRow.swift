////
//  RepositoryChangeRow.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryChangeRow: View {
    @Environment(\.backgroundProminence) private var backgroundProminence
    let change: RepositoryChange

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: presentation.code)
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: change.path)
                    .lineLimit(1)
                if let originalPath {
                    Text(verbatim: originalPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(presentation.name))
        .accessibilityValue(Text(verbatim: accessiblePath))
        // Applied after the accessibility modifiers, and the order is load-bearing.
        // `accessibilityElement(children: .combine)` merges this row's children into one element;
        // a style modifier applied *before* it goes into the tree being merged, which changes the
        // resulting element's identity every time the tint is re-evaluated. XCUITest resolves a
        // row once and then acts on it, so a reference taken before a re-evaluation stops
        // matching — `CommitUITests` fails with "No matches found for Descendant" when this sits
        // above the merge. Styling applies to the row either way, so the position costs nothing.
        .foregroundStyle(tint)
    }

    /// The color the letter and the path carry, and the reason the row reads its own background.
    ///
    /// A selected row is filled with the selection color, and a tint chosen for the list's own
    /// background has no contrast guarantee against that fill. `.primary` on an increased-prominence
    /// background is the system's own answer, so the selected row stays legible and the letter keeps
    /// carrying the state on its own — the color is never the only indication of what a row is.
    private var tint: AnyShapeStyle {
        backgroundProminence == .increased
            ? AnyShapeStyle(.primary)
            : AnyShapeStyle(change.kind.tint)
    }

    private var presentation: (code: String, name: LocalizedStringResource) {
        switch change.kind {
        case .modified: ("M", .modified)
        case .added: ("A", .added)
        case .deleted: ("D", .deleted)
        case .renamed: ("R", .renamed)
        case .typeChanged: ("T", .typeChanged)
        case .untracked: ("?", .untracked)
        case .conflict: ("U", .conflict)
        }
    }

    private var accessiblePath: String {
        if let originalPath {
            return "\(String(localized: .from)) \(originalPath), "
                + "\(String(localized: .to)) \(change.path)"
        }
        return change.path
    }

    private var originalPath: String? {
        if case .renamed(let originalPath) = change.kind {
            return originalPath
        }
        return nil
    }
}

extension RepositoryChangeKind {

    /// What a change kind is tinted in the Changes list, following the convention a Git user
    /// already carries over from other clients: green for what Git has been told to add, blue for
    /// a tracked path that moved or changed, red for what Git does not know about, and the
    /// secondary color for a path that is on its way out.
    ///
    /// Untracked and Conflict share red because both are states the user has to act on before a
    /// Commit; `?` and `U` are what tells them apart, so the pair stays readable under
    /// Differentiate Without Color.
    var tint: Color {
        switch self {
        case .modified, .renamed, .typeChanged: .blue
        case .added: .green
        case .untracked, .conflict: .red
        case .deleted: .secondary
        }
    }
}
