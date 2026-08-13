////
//  RepositoryPickerButton.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryPickerButton: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        Button(action: presentRepositoryPicker) {
            Label {
                VStack(alignment: .leading) {
                    Text(
                        verbatim: state.repository?.name ?? String(localized: .openRepository)
                    )
                        .font(.headline)
                    if let repository = state.repository {
                        Text(verbatim: repository.rootURL.normalizedFilePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } icon: {
                Image(systemName: "folder")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            // The padding and the leading alignment only position the label; they do not make
            // the surrounding row hit-testable. Without an explicit content shape a plain button
            // only reacts to clicks that land on the glyphs themselves, so once a Repository is
            // open — the label is two lines then, with a gap and trailing space around it — most
            // clicks on the row are swallowed and the Repository can never be replaced.
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!state.canReplaceRepository)
        .accessibilityLabel(Text(.openRepository))
        .accessibilityValue(Text(verbatim: state.repository?.name ?? ""))
        .accessibilityIdentifier("baseline.repositoryPicker")
    }

    private func presentRepositoryPicker() {
        state.isPresentingRepositoryPicker = true
    }
}
