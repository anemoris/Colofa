////
//  FetchTagsSheet.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Which remote a Fetch Tags downloads from, when the Repository has more than one.
///
/// It opens with `origin` selected but fetches nothing until its own button is pressed: tag names
/// are shared across remotes, so a preselection is a starting point rather than an answer given
/// on the user's behalf.
struct FetchTagsSheet: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if let selection = state.tagFetchSelection {
            FetchTagsForm(selection: selection)
        }
    }
}

private struct FetchTagsForm: View {
    @Environment(WorkspaceState.self) private var state
    let selection: TagFetchSelection

    var body: some View {
        VStack(alignment: .leading) {
            Text(.fetchTags)
                .font(.headline)

            Text(.fetchTagsRemoteDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(selection: remote) {
                ForEach(selection.remotes, id: \.self) { name in
                    Text(verbatim: name)
                        .tag(name)
                }
            } label: {
                Text(.remote)
            }
            .accessibilityIdentifier("repository.fetchTags.remote")

            HStack {
                Spacer(minLength: 0)
                Button(.cancel, role: .cancel, action: state.cancelTagFetch)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repository.fetchTags.cancel")
                Button(.fetchTags, action: confirm)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.canFetchTags)
                    .accessibilityIdentifier("repository.fetchTags.confirm")
            }
        }
        .padding()
        .frame(width: LayoutMetrics.Remote.dialogWidth)
    }

    private var remote: Binding<String> {
        Binding(
            get: { state.tagFetchSelection?.selectedRemote ?? selection.selectedRemote },
            set: { state.tagFetchSelection?.selectedRemote = $0 }
        )
    }

    private func confirm() {
        Task {
            await state.confirmTagFetch()
        }
    }
}
