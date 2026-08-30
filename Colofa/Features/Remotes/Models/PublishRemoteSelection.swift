////
//  PublishRemoteSelection.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The open Publish dialog: which remote a Branch nobody has pushed yet is created on.
///
/// It opens only when Git's own configuration answered nothing and the Repository has more than
/// one remote. A single remote is the answer rather than a question, and a configured push remote
/// is the user's answer already given — asking again would be asking the user to repeat their own
/// configuration back to Colofa.
///
/// `origin` starts selected because that is the name Git itself gives the remote a clone came
/// from, but a preselection is not a confirmation: nothing is published until the dialog's own
/// button is pressed, so a Branch never appears on a remote the user did not name.
nonisolated struct PublishRemoteSelection: Equatable, Sendable {

    /// The name Git itself gives the remote a clone came from, which is what the dialog
    /// preselects.
    static let conventionalRemote = "origin"

    let branch: String
    let remotes: [String]
    var selectedRemote: String

    init?(branch: String, remotes: [String]) {
        guard let first = remotes.first else {
            return nil
        }
        self.branch = branch
        self.remotes = remotes
        selectedRemote = remotes.contains(Self.conventionalRemote)
            ? Self.conventionalRemote
            : first
    }

    /// Whether this dialog still describes `repository`.
    ///
    /// The same reload that can happen under a Push confirmation can happen under this one, and
    /// what it asks about can stop being true: the Branch may no longer be the one checked out, it
    /// may have acquired an upstream from elsewhere — which makes this the wrong question — or the
    /// selected remote may have been removed.
    func describes(_ repository: RepositorySnapshot) -> Bool {
        // Matched as a pattern rather than compared: `RepositoryUpstream` is a Main Actor type,
        // and its `Equatable` conformance is not reachable from here.
        guard case .branch(let current) = repository.head,
              current == branch,
              case .none = repository.upstream else {
            return false
        }
        return repository.remotes.contains { $0.name == selectedRemote }
    }
}
