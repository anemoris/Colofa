////
//  DetailView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct DetailView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if let selection = state.selectedChange,
           let change = state.change(for: selection) {
            VStack(spacing: 0) {
                VStack(alignment: .leading) {
                    HStack {
                        RepositoryChangeRow(change: change)
                        Spacer()
                        RepositoryChangeActionButton(
                            change: change,
                            isStaged: selection.isStaged
                        )
                        .accessibilityIdentifier("repository.detail.action")
                    }
                    if change.isConflict {
                        Text(.resolveConflictBeforeStaging)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()

                Divider()
                Spacer()
            }
        } else {
            ContentUnavailableView {
                Label(.nothingSelected, systemImage: "doc.text.magnifyingglass")
            } description: {
                Text(.nothingSelectedDescription)
            }
            .accessibilityIdentifier("baseline.empty.detail")
        }
    }
}
