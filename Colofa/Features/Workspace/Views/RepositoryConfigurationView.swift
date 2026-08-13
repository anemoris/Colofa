////
//  RepositoryConfigurationView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import SwiftUI

struct RepositoryConfigurationView: View {
    @Environment(WorkspaceState.self) private var state
    let configuration: GitConfigurationSnapshot

    var body: some View {
        @Bindable var state = state

        VStack(alignment: .leading, spacing: 12) {
            Label(.configuration, systemImage: "gearshape")
                .font(.headline)

            Picker(String(localized: .configurationEditingScope), selection: $state.configurationEditingScope) {
                ForEach(GitConfigurationEditScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .accessibilityIdentifier("repository.configuration.scope")

            Text(state.configurationEditingScope.destinationDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(GitConfigurationKey.allCases) { key in
                RepositoryConfigurationField(
                    configuration: configuration,
                    key: key,
                    editingScope: state.configurationEditingScope
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
