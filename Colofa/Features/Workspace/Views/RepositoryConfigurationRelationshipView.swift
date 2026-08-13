////
//  RepositoryConfigurationRelationshipView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import SwiftUI

struct RepositoryConfigurationRelationshipView: View {
    let relationship: GitConfigurationRelationship
    let canRemoveOverride: Bool
    let removeOverride: () -> Void

    var body: some View {
        let content = RepositoryConfigRelationshipContent(
            relationship: relationship
        )

        VStack(alignment: .leading, spacing: 4) {
            RepositoryConfigurationNote(
                message: content.message,
                systemImage: content.systemImage,
                isWarning: content.isWarning
            )

            if let removalTitle = content.removalTitle {
                Button(removalTitle, action: removeOverride)
                    .buttonStyle(.link)
                    .disabled(!canRemoveOverride)
                    .accessibilityIdentifier(
                        "repository.configuration.removeOverride.\(relationship.entry.key.rawValue)"
                    )
            }
        }
    }
}
