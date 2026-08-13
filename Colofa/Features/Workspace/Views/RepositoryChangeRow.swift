////
//  RepositoryChangeRow.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryChangeRow: View {
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
