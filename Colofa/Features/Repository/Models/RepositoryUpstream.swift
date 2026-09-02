////
//  RepositoryUpstream.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The upstream a local Branch tracks, and where the Branch stands relative to it.
///
/// The type stays Main Actor-isolated, as it has been; the members a nonisolated parser, actor,
/// or fixture reaches for are spelled `nonisolated` one at a time rather than by relaxing the
/// type, because `PublishRemoteSelection` relies on its `Equatable` conformance staying out of
/// reach from there.
struct RepositoryUpstream: Equatable, Sendable {
    let name: String
    let position: UpstreamPosition

    nonisolated init(name: String, position: UpstreamPosition) {
        self.name = name
        self.position = position
    }

    /// The ordinary upstream: one Git counted both directions against.
    nonisolated init(name: String, ahead: Int, behind: Int) {
        self.init(name: name, position: .counted(ahead: ahead, behind: behind))
    }

    /// Commits the Branch has and its upstream does not, or `nil` when Git counted neither.
    nonisolated var ahead: Int? {
        guard case .counted(let ahead, _) = position else { return nil }
        return ahead
    }

    /// Commits the upstream has and the Branch does not, or `nil` when Git counted neither.
    nonisolated var behind: Int? {
        guard case .counted(_, let behind) = position else { return nil }
        return behind
    }
}

/// Where a local Branch stands relative to the upstream it names.
///
/// Git omits `branch.ab` from `status --porcelain=v2` in exactly two situations, and neither of
/// them means the two are level: the Branch is Unborn, so it has no Commit to count from; or the
/// upstream ref itself is gone, which is what a Fetch Remotes leaves behind once the remote says
/// the Branch it tracked was deleted. Reading that silence as `+0 -0` would report a Branch as
/// level with something that is not there, so each case is carried as itself.
nonisolated enum UpstreamPosition: Equatable, Sendable {

    /// Git counted both directions.
    case counted(ahead: Int, behind: Int)

    /// The remote-tracking Branch this upstream names no longer exists, so how far apart the two
    /// stand is unanswerable rather than zero.
    ///
    /// The local Branch keeps its `branch.<name>.merge` configuration: pruning removes a
    /// remote-tracking ref and nothing else, and editing or deleting the Branch that pointed at
    /// it is not something a Fetch does on the user's behalf.
    case gone

    /// Nothing to count from yet: the Branch is Unborn, so it has no Commit of its own.
    case unborn
}
