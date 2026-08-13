////
//  GitUnavailableView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct GitUnavailableView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        ContentUnavailableView {
            Label(.gitUnavailable, systemImage: "terminal")
        } description: {
            VStack {
                Text(.gitUnavailableDescription)
                Text(verbatim: "xcode-select --install")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
        } actions: {
            Button(.checkAgain, systemImage: "arrow.clockwise", action: checkAgain)
        }
        .accessibilityIdentifier("repository.gitUnavailable")
    }

    private func checkAgain() {
        Task {
            await state.retryGitDiscovery()
        }
    }
}
