////
//  WorkspaceContentView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct WorkspaceContentView: View {
    @Environment(WorkspaceState.self) private var state
    let section: WorkspaceSection

    var body: some View {
        VStack(spacing: 0) {
            Label {
                Text(section.title)
                    .font(.headline)
            } icon: {
                Image(systemName: section.systemImage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            if state.isLoadingRepository && state.repository == nil {
                ContentUnavailableView {
                    ProgressView()
                    Text(.loadingRepository)
                } description: {
                    Text(.loadingRepositoryDescription)
                }
            } else if let repository = state.repository {
                switch section {
                case .changes:
                    RepositoryChangesView(repository: repository)
                case .history:
                    HistoryView()
                case .stashes:
                    StashesView()
                }
            } else {
                ContentUnavailableView {
                    Label(.noRepositorySelected, systemImage: "folder.badge.questionmark")
                } description: {
                    Text(.openRepositoryDescription)
                } actions: {
                    Button(.openRepository, action: openRepository)
                }
                .accessibilityIdentifier("repository.empty")
            }
        }
    }

    private func openRepository() {
        state.isPresentingRepositoryPicker = true
    }
}
