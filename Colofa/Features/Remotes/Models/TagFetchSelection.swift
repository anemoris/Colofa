////
//  TagFetchSelection.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The open Fetch Tags dialog: which remote every tag would be downloaded from.
///
/// It only opens when the Repository has more than one remote; a single remote is the answer
/// rather than a question. `origin` starts selected because that is the name Git itself gives the
/// remote a clone came from, but a preselection is not a confirmation: nothing is fetched until
/// the dialog's own button is pressed, so tags never arrive from a remote the user did not name.
nonisolated struct TagFetchSelection: Equatable, Sendable {

    /// The name Git gives the remote a clone came from, which is what the dialog preselects.
    static let conventionalRemote = "origin"

    let remotes: [String]
    var selectedRemote: String

    init?(remotes: [String]) {
        guard let first = remotes.first else {
            return nil
        }
        self.remotes = remotes
        selectedRemote = remotes.contains(Self.conventionalRemote)
            ? Self.conventionalRemote
            : first
    }
}
