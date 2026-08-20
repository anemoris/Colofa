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

            // One selection for sections and Refs alike: a Ref that stayed highlighted while
            // Changes was on screen would claim to be showing something it is not.
            List(selection: $state.sidebarSelection) {
                Section(String(localized: .workspace)) {
                    ForEach(WorkspaceSection.allCases) { section in
                        Label {
                            Text(section.title)
                        } icon: {
                            Image(systemName: section.systemImage)
                        }
                        .tag(SidebarSelection.section(section))
                        .accessibilityIdentifier(section.accessibilityIdentifier)
                    }
                }

                Section(String(localized: .branches)) {
                    if let repository = state.repository {
                        RepositoryHeadLabel(
                            head: repository.head,
                            showsCurrentBranchIndicator: true
                        )
                            .tag(SidebarSelection.reference(.head))
                            .accessibilityIdentifier("repository.head")
                            .contextMenu {
                                SidebarReferenceMenu(reference: .head)
                            }
                        ForEach(repository.localBranches, id: \.self) { branch in
                            if repository.head != .branch(branch) {
                                SidebarReferenceLabel(
                                    reference: .localBranch(branch),
                                    systemImage: "arrow.triangle.branch"
                                )
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
                            SidebarReferenceLabel(
                                reference: .remoteBranch(branch),
                                systemImage: "arrow.triangle.branch"
                            )
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
                            SidebarReferenceLabel(reference: .tag(tag), systemImage: "tag")
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

/// One selectable Ref. Selecting it inspects its History; it never checks anything out.
private struct SidebarReferenceLabel: View {
    let reference: GitReference
    let systemImage: String

    var body: some View {
        Label {
            Text(verbatim: reference.name ?? "")
        } icon: {
            Image(systemName: systemImage)
        }
        .tag(SidebarSelection.reference(reference))
        .accessibilityIdentifier(reference.accessibilityIdentifier)
        .contextMenu {
            SidebarReferenceMenu(reference: reference)
        }
    }
}

private struct SidebarReferenceMenu: View {
    @Environment(WorkspaceState.self) private var state
    let reference: GitReference

    var body: some View {
        Button(.viewHistory) {
            state.select(.reference(reference))
        }
        if state.branchName(of: reference) != nil {
            Button(.copyBranchName) {
                state.copyBranchName(of: reference)
            }
            .accessibilityIdentifier("repository.ref.copyBranchName")
        }
    }
}
