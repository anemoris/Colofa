////
//  RepositoryChangeListRow.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryChangeListRow: View {
    let change: RepositoryChange
    let isStaged: Bool

    var body: some View {
        HStack {
            RepositoryChangeRow(change: change)
                .accessibilityIdentifier(rowIdentifier)
            Spacer()
            RepositoryChangeActionButton(change: change, isStaged: isStaged)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .accessibilityIdentifier(actionIdentifier)
        }
        .contextMenu {
            RepositoryChangeActions(change: change, isStaged: isStaged)
        }
    }

    private var actionIdentifier: String {
        "repository.\(isStaged ? "staged" : "unstaged").action.\(change.path)"
    }

    private var rowIdentifier: String {
        "repository.\(isStaged ? "staged" : "unstaged").\(change.path)"
    }
}
