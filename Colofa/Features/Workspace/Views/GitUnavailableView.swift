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

    /// Shown exactly as it has to be typed. A command is not copy: translating it would leave the
    /// user with a line that does not run.
    private static let installCommand = "xcode-select --install"

    var body: some View {
        ContentUnavailableView {
            Label(.gitUnavailable, systemImage: "terminal")
        } description: {
            VStack {
                Text(.gitUnavailableDescription)
                Text(verbatim: Self.installCommand)
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
