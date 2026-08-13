////
//  SidebarView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct SidebarView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 0) {
            RepositoryPickerButton()
            Divider()

            List(selection: $state.selectedSection) {
                Section(String(localized: .workspace)) {
                    ForEach(WorkspaceSection.allCases) { section in
                        Label {
                            Text(section.title)
                        } icon: {
                            Image(systemName: section.systemImage)
                        }
                        .tag(section)
                        .accessibilityIdentifier(section.accessibilityIdentifier)
                    }
                }

                Section(String(localized: .branches)) {
                    if let repository = state.repository {
                        RepositoryHeadLabel(
                            head: repository.head,
                            showsCurrentBranchIndicator: true
                        )
                            .accessibilityIdentifier("repository.head")
                        ForEach(repository.localBranches, id: \.self) { branch in
                            if repository.head != .branch(branch) {
                                Label {
                                    Text(verbatim: branch)
                                } icon: {
                                    Image(systemName: "arrow.triangle.branch")
                                }
                            }
                        }
                    } else {
                        Label(.noBranches, systemImage: "arrow.triangle.branch")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(String(localized: .remotes)) {
                    if let repository = state.repository,
                       !repository.remotes.isEmpty || !repository.remoteBranches.isEmpty {
                        ForEach(repository.remotes) { remote in
                            Label {
                                Text(verbatim: remote.name)
                            } icon: {
                                Image(systemName: "cloud")
                            }
                        }
                        ForEach(repository.remoteBranches, id: \.self) { branch in
                            Label {
                                Text(verbatim: branch)
                            } icon: {
                                Image(systemName: "arrow.triangle.branch")
                            }
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label(.noRemotes, systemImage: "cloud")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(String(localized: .tags)) {
                    if let repository = state.repository, !repository.tags.isEmpty {
                        ForEach(repository.tags, id: \.self) { tag in
                            Label {
                                Text(verbatim: tag)
                            } icon: {
                                Image(systemName: "tag")
                            }
                        }
                    } else {
                        Label(.noTags, systemImage: "tag")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}
