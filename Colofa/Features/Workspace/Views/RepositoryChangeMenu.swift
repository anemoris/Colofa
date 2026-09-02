////
//  RepositoryChangeMenu.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The Diff pane's visible menu of everything the path on screen offers.
///
/// The list row reaches the same actions through its context menu, which is where a macOS user
/// looks first. This is what keeps them reachable without one: a context menu is discovered by
/// trying, and Discard Changes must not be something only a right-click reveals.
struct RepositoryChangeMenu: View {
    let change: RepositoryChange
    let isStaged: Bool

    var body: some View {
        Menu {
            RepositoryChangeActions(change: change, isStaged: isStaged)
        } label: {
            Label(.fileActions, systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityIdentifier("repository.detail.fileActions")
    }
}
