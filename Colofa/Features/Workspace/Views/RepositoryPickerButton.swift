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
                // The name alone. The path is the status bar's to report and the inspector's to
                // spell out in full; repeating it here said the Repository's own name twice, once
                // as the title and once as the tail of the path directly under it.
                Text(verbatim: state.repository?.name ?? String(localized: .openRepository))
                    .font(.headline)
            } icon: {
                Image(systemName: "folder")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            // The padding and the leading alignment only position the label; they do not make
            // the surrounding row hit-testable. Without an explicit content shape a plain button
            // only reacts to clicks that land on the glyphs themselves, so most of the row — the
            // padding around the label and the trailing space beside it — swallows its clicks and
            // the Repository can never be replaced.
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
