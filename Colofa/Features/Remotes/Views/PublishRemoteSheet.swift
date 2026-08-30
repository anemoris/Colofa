////
//  PublishRemoteSheet.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Which remote a Branch nobody has pushed yet is created on, when the Repository has more than
/// one and its configuration named none.
///
/// It opens with `origin` selected but publishes nothing until its own button is pressed: which
/// remote a Branch belongs on is a decision about who gets to see it, and a preselection is a
/// starting point rather than an answer given on the user's behalf.
struct PublishRemoteSheet: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        if case .publishRemote(let selection) = state.pushDialog {
            PublishRemoteForm(selection: selection)
        }
    }
}

private struct PublishRemoteForm: View {
    @Environment(WorkspaceState.self) private var state
    let selection: PublishRemoteSelection

    var body: some View {
        VStack(alignment: .leading) {
            Text(.publish)
                .font(.headline)

            Text(.publishRemoteDescription(selection.branch))
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
            .accessibilityIdentifier("repository.publish.remote")

            HStack {
                Spacer(minLength: 0)
                Button(.cancel, role: .cancel, action: state.cancelPublishRemote)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("repository.publish.cancel")
                Button(.publish, action: confirm)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.canPush)
                    .accessibilityIdentifier("repository.publish.confirm")
            }
        }
        .padding()
        .frame(width: LayoutMetrics.Remote.dialogWidth)
    }

    private var remote: Binding<String> {
        Binding(
            get: { state.pushDialog?.publishRemote?.selectedRemote ?? selection.selectedRemote },
            set: { state.pushDialog?.publishRemote?.selectedRemote = $0 }
        )
    }

    private func confirm() {
        Task {
            await state.confirmPublishRemote()
        }
    }
}
