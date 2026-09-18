////
//  StashesView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The Stashes the open Repository holds.
///
/// Reading them never changes the Repository: this pane selects an entry and nothing more. What
/// restores or removes one is a separate, explicit action.
struct StashesView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        StashesContentView()
            // Keyed on the Repository read as well as the Repository itself, so a Stash created,
            // dropped, or applied re-reads rather than leaving the previous list on screen.
            .task(id: state.stashIdentity) {
                await state.loadStashes()
            }
    }
}

private struct StashesContentView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        switch state.stashes {
        case nil, .loading?:
            ProgressView(String(localized: .loadingStashes))
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("repository.stashes.loading")
        case .failed(let error)?:
            ContentUnavailableView {
                Label(.stashesLoadFailed, systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.message)
            } actions: {
                Button(.reloadStashes, action: reload)
            }
            .accessibilityIdentifier("repository.stashes.failure")
        case .loaded(let stashes)? where stashes.isEmpty:
            // The identifier sits on the label rather than on the whole view: an identifier on a
            // `ContentUnavailableView` reaches every element inside it, and Stash below would
            // then answer to the empty state's name rather than to its own.
            ContentUnavailableView {
                Label(.noStashes, systemImage: "tray.full")
                    .accessibilityIdentifier("baseline.empty.stashes")
            } description: {
                Text(.noStashesDescription)
            } actions: {
                StashButton()
            }
        case .loaded(let stashes)?:
            StashListView(stashes: stashes)
        }
    }

    private func reload() {
        Task {
            await state.loadStashes()
        }
    }
}

/// Stash, offered where an empty list makes it the obvious next thing.
///
/// The same action the toolbar and the Repository menu carry, opening the same sheet. It says why
/// it is unavailable rather than disappearing, so a Repository with nothing to save explains
/// itself in the one place the user went looking.
private struct StashButton: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        Button(.stash, action: state.beginCreatingStash)
            .disabled(!state.canBeginCreatingStash)
            .help(String(localized: state.stashCreationUnavailabilityReason?.message ?? .stashHelp))
            .accessibilityIdentifier("repository.stashes.create")
    }
}

private struct StashListView: View {
    @Environment(WorkspaceState.self) private var state
    let stashes: [Stash]

    var body: some View {
        @Bindable var state = state

        List(selection: $state.selectedStashID) {
            ForEach(stashes) { stash in
                StashRow(stash: stash)
                    .tag(stash.id)
            }
        }
        .listStyle(.inset)
        .accessibilityIdentifier("repository.stashes")
    }
}
