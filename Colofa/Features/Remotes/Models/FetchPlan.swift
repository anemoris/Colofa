////
//  FetchPlan.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which remotes one Fetch of every remote actually contacts.
///
/// Git's own `remote.<name>.skipFetchAll` decides this, so Colofa reads that configuration rather
/// than inventing an eligibility rule of its own. It is read when Fetch runs rather than with the
/// Repository: whether a remote is skipped is a property of fetching, and a value Git refuses to
/// read should fail the Fetch rather than make the Repository unopenable.
nonisolated struct FetchPlan: Equatable, Sendable {

    /// The eligible remotes, in the order the Repository lists them.
    let remotes: [String]

    /// Whether Git's configuration leaves a Fetch of every remote with no remote to contact,
    /// which is a Fetch that ran no command rather than one that found nothing to download.
    var isEmpty: Bool {
        remotes.isEmpty
    }

    static func evaluate(
        remotes: [RepositoryRemote],
        skipping skippedRemotes: Set<String>
    ) -> Self {
        Self(remotes: remotes.map(\.name).filter { !skippedRemotes.contains($0) })
    }
}
