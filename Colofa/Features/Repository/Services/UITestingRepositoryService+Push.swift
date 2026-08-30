////
//  UITestingRepositoryService+Push.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// What the stubbed backend answers about where a Push goes, and what it does with one that the
/// remote accepts.
///
/// Grouped apart from Fetch because these commands write to a remote rather than read from one:
/// what they leave behind is a Branch that now exists somewhere else.
extension UITestingRepositoryService {
    func publishRemote(_ request: PushTargetRequest) -> String? {
        UITestingPush.publishRemote(arguments: arguments)
    }

    func pushTarget(_ request: PushTargetRequest) -> PushTarget? {
        UITestingPush.target(arguments: arguments)
    }

    func pushDestination(_ request: PushDestinationRequest) throws -> PushDestination {
        try UITestingPush.destination(of: request.remote, arguments: arguments)
    }

    /// Records what one accepted Publish or Push left behind: a Branch that is no longer ahead of
    /// its upstream, and — the first time — an upstream at all.
    func accept(_ command: [String], in snapshot: RepositorySnapshot) {
        let upstream = UITestingPush.publishedUpstream(command)
        publish(
            replacing(
                in: snapshot,
                remoteBranches: snapshot.remoteBranches.contains(upstream)
                    ? snapshot.remoteBranches
                    : (snapshot.remoteBranches + [upstream]).sorted(),
                upstream: UITestingPush.settledUpstream(command)
            )
        )
    }
}
#endif
