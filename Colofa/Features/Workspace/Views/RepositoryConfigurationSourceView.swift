////
//  RepositoryConfigurationSourceView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import SwiftUI

struct RepositoryConfigurationSourceView: View {
    let entry: GitConfigurationEntry
    let isEffective: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: isEffective ? "checkmark.circle" : "arrow.turn.down.right")
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.scope.title)
                    if isEffective {
                        Text(.configurationEffective)
                    }
                }
                Text(verbatim: entry.origin.displayLocation())
                    .textSelection(.enabled)
                if entry.value.isEmpty {
                    Text(.configurationEmptyValue)
                        .textSelection(.enabled)
                } else {
                    Text(verbatim: entry.value)
                        .textSelection(.enabled)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            "repository.configuration.source.\(entry.key.rawValue).\(entry.scope.rawValue)"
        )
    }
}
