////
//  RepositoryServiceStub+Push.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// What the fixture answers about Publish and Push.
///
/// Grouped apart because these behave differently from the rest: they write to a remote, and the
/// one thing that can stop them from doing so is a lease the remote no longer honors.
extension RepositoryServiceStub {
    func configuredPublishRemote(_ request: PushTargetRequest) throws -> String? {
        publishRemoteRequests.append(request)
        if let pushTargetError {
            throw pushTargetError
        }
        return publishRemote
    }

    func configuredPushTarget(_ request: PushTargetRequest) throws -> PushTarget? {
        pushTargetRequests.append(request)
        if let pushTargetError {
            throw pushTargetError
        }
        return pushTarget
    }

    /// The address this fixture's remote resolves to, answered in the order a test configured.
    ///
    /// Each read consumes one answer while more remain, so a test can drive the one case a single
    /// value cannot express: a remote whose address changed between the confirmation opening and
    /// its button being pressed.
    func configuredPushDestination(_ request: PushDestinationRequest) throws -> PushDestination {
        pushDestinationRequests.append(request)
        if let pushDestinationError {
            throw pushDestinationError
        }
        guard var answers = pushDestinations[request.remote], let answer = answers.first else {
            return pushDestination(remote: request.remote)
        }
        if answers.count > 1 {
            answers.removeFirst()
            pushDestinations[request.remote] = answers
        }
        return answer
    }

    func recordedPushDestinationRequests() -> [PushDestinationRequest] {
        pushDestinationRequests
    }

    func recordedPublishRemoteRequests() -> [PushTargetRequest] {
        publishRemoteRequests
    }

    func recordedPushTargetRequests() -> [PushTargetRequest] {
        pushTargetRequests
    }

    /// Answers a Force Push with Lease the way a real remote does.
    ///
    /// The lease is compared against what the remote holds *now*, not against what the Push
    /// expected — which is the whole mechanism: a remote that moved after the confirmation was
    /// opened refuses rather than being overwritten. A command carrying no lease is not checked,
    /// because there is nothing to compare.
    ///
    /// - Returns: `nil` when the command may go on.
    func leaseRefusal(_ arguments: [String]) -> RepositoryOpenError? {
        guard let option = arguments.first(where: { $0.hasPrefix(Self.leaseOption) }),
              let expected = option.split(separator: ":").last.map(String.init),
              let remoteObjectID,
              expected != remoteObjectID else {
            return nil
        }
        return .commandFailed(
            GitFailureDetails(
                command: "git push",
                output: """
                    error: failed to push some refs
                    !\trefs/heads/main:refs/heads/main\t[rejected] (stale info)
                    """,
                exitStatus: 1
            )
        )
    }

    /// The one spelling of force this project allows, which is also the only one a fixture ever
    /// has to recognize.
    static let leaseOption = "--force-with-lease="
}
