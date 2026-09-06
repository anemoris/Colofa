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
                    FetchRemotesButton()
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
                    FetchTagsButton()
                }
            }
            .listStyle(.sidebar)
        }
    }
}

/// Fetch Remotes, which lives in the Remotes section it reconciles.
///
/// The toolbar's Fetch adds no option and leaves each remote's own configuration in charge, so a
/// remote-tracking Branch whose Branch was deleted on the server stays listed here until someone
/// asks. This is that asking, and it sits beside the refs it removes rather than in the toolbar,
/// where it would read as something the ordinary Fetch does by itself.
private struct FetchRemotesButton: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        Button(action: fetchRemotes) {
            Label(.fetchRemotes, systemImage: "arrow.down.circle")
                .frame(maxWidth: .infinity, alignment: .leading)
                // The whole row answers the click, not only the words in it.
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(String(localized: state.fetchUnavailabilityReason?.message ?? .fetchRemotesHelp))
        .disabled(!state.canFetchRemotes)
        .accessibilityIdentifier("repository.remotes.fetch")
    }

    private func fetchRemotes() {
        Task {
            await state.fetchRemotes()
        }
    }
}

/// Fetch Tags, which lives in the Tags section it adds to.
///
/// Tags outside a fetched branch's History only arrive when they are asked for, so the action
/// sits beside the tags rather than in the toolbar, where it would read as part of the ordinary
/// Fetch it deliberately is not.
private struct FetchTagsButton: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        Button(action: fetchTags) {
            Label(.fetchTags, systemImage: "arrow.down.circle")
                .frame(maxWidth: .infinity, alignment: .leading)
                // The whole row answers the click, not only the words in it.
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(String(localized: state.fetchUnavailabilityReason?.message ?? .fetchTagsHelp))
        .disabled(!state.canFetchTags)
        .accessibilityIdentifier("repository.tags.fetch")
    }

    private func fetchTags() {
        Task {
            await state.fetchTags()
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
        if state.checkoutTarget(for: reference) != nil {
            Button(.checkout, action: checkout)
                .disabled(!state.canCheckout(reference))
                .accessibilityIdentifier("repository.ref.checkout")
        }
        if state.branchName(of: reference) != nil {
            Button(.copyBranchName) {
                state.copyBranchName(of: reference)
            }
            .accessibilityIdentifier("repository.ref.copyBranchName")
        }
        // Only on a Branch, because Merge has nothing to act on for a tag or for HEAD. It stays
        // on the current Branch's own row, disabled and saying why, for the same reason Delete
        // Branch does. `DESIGN.md` §3 keeps it out of the toolbar: merging is infrequent and
        // consequential, so it lives where the Ref it acts on is.
        if state.mergeSource(of: reference) != nil {
            Divider()
            Button(.merge, action: merge)
                .disabled(!state.canMerge(reference))
                .help(
                    String(
                        localized: state.mergeUnavailabilityReason(for: reference)?.message
                            ?? .mergeHelp
                    )
                )
                .accessibilityIdentifier("repository.ref.merge")
        }
        // Offered on the current Branch's own row too, disabled and saying why: an action that
        // disappeared there would leave the user hunting for one Colofa deliberately refuses.
        if state.deletableBranchName(of: reference) != nil {
            Divider()
            Button(.deleteBranch, action: deleteBranch)
                .disabled(!state.canDeleteBranch(reference))
                .help(
                    String(
                        localized: state.branchDeletionUnavailabilityReason(for: reference)?.message
                            ?? .deleteBranchHelp
                    )
                )
                .accessibilityIdentifier("repository.ref.deleteBranch")
        }
    }

    private func checkout() {
        Task {
            await state.checkout(reference)
        }
    }

    private func merge() {
        state.beginMerging(reference)
    }

    private func deleteBranch() {
        Task {
            await state.beginDeletingBranch(reference)
        }
    }
}
