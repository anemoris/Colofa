////
//  PushTarget.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Where a Push of one Branch goes, and what its remote held the last time Colofa looked.
///
/// Every part of this is Git's own answer rather than something split out of the short upstream
/// name a snapshot carries. `origin/main` cannot be taken apart by hand: a remote may itself be
/// named with a slash, and guessing wrong would push to a remote the confirmation never showed.
nonisolated struct PushTarget: Equatable, Sendable {

    /// The remote Git resolves for this Branch's upstream.
    let remote: String

    /// The full ref on the remote, such as `refs/heads/main`. It is both the destination of the
    /// refspec and the ref a lease names, so the two can never disagree.
    let remoteRef: String

    /// The upstream as the user reads it, such as `origin/main`, which is what the confirmation
    /// shows and what a refusal names.
    let upstream: String

    /// The remote-tracking Ref `expectedObjectID` is read from, such as `refs/remotes/origin/main`.
    ///
    /// Carried rather than assembled from the two names above: a remote-tracking Ref is Git's own
    /// answer, and building one by joining a remote name to a Branch name is the guess this type
    /// exists to avoid.
    let trackingRef: String

    /// What the remote-tracking ref points at, which is the exact object a Force Push with Lease
    /// requires the remote to still hold.
    ///
    /// `nil` when there is no remote-tracking ref to read — an upstream configured for a Branch
    /// nobody has fetched yet. No lease can be taken against a value nobody observed, so a Push
    /// in that state can only be an ordinary one.
    let expectedObjectID: String?

    nonisolated init(
        remote: String,
        remoteRef: String,
        upstream: String,
        trackingRef: String,
        expectedObjectID: String? = nil
    ) {
        self.remote = remote
        self.remoteRef = remoteRef
        self.upstream = upstream
        self.trackingRef = trackingRef
        self.expectedObjectID = expectedObjectID
    }

    /// The same target, reporting `objectID` as what the remote held when it was read.
    ///
    /// Separate from the rest because it is a second question: `for-each-ref` reports where a
    /// Push goes, and only a read of the remote-tracking ref itself says what is there now.
    nonisolated func expecting(_ objectID: String?) -> Self {
        Self(
            remote: remote,
            remoteRef: remoteRef,
            upstream: upstream,
            trackingRef: trackingRef,
            expectedObjectID: objectID.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}
