////
//  SidebarSelection.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What one click in the sidebar selected.
///
/// Refs and workspace sections share a single selection because they share a single list: macOS
/// gives a sidebar one selected row, and a Ref that stayed highlighted while Changes was on
/// screen would claim to be showing something it is not.
nonisolated enum SidebarSelection: Hashable, Sendable {
    case section(WorkspaceSection)
    /// Inspection only. Selecting a Ref never moves HEAD and never touches the working tree;
    /// Checkout is a separate, explicit action.
    case reference(GitReference)
}
