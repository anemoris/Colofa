////
//  RepositoryInspector.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryInspector: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        VStack(alignment: .leading) {
            Label(.repositoryInfo, systemImage: "info.circle")
                .font(.headline)

            if let repository = state.repository {
                RepositoryInformationView(
                    repository: repository,
                    lastFetchDate: state.lastFetchDate
                )
            } else {
                ContentUnavailableView {
                    Label(.noRepositorySelected, systemImage: "folder.badge.questionmark")
                } description: {
                    Text(.repositoryInfoDescription)
                }
                Spacer()
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(.repositoryInfo))
        .accessibilityIdentifier("baseline.repositoryInspector")
    }
}
