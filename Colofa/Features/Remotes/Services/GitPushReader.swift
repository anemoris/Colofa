////
//  GitPushReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The read-only questions Publish and Push ask before anything leaves for a remote: where this
/// Branch is configured to go, and what its upstream held the last time Colofa looked.
///
/// Both are asked when the command is reached rather than carried on a snapshot. Where a Push goes
/// is configuration that decides what a command does rather than what the Repository is, and the
/// expected object is only meaningful at the moment a confirmation opens.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads these from an actor.
nonisolated struct GitPushReader {
    let git: GitProcess

    /// The remote Git's own configuration would push `branch` to, or `nil` when it names none.
    ///
    /// Each key is asked in the order Git overrules them and the first answer wins, so Colofa
    /// honors the configuration rather than reproducing the rule behind it. Git's own fallback to
    /// `origin` is not applied here: with nothing configured, choosing among the Repository's
    /// actual remotes is Publish's decision to make and, where it is ambiguous, the user's.
    func remote(_ request: PushTargetRequest) async throws -> String? {
        for key in PushCommand.remoteKeys(for: request.branch) {
            let value = String(
                gitBytes: try await git.dataAllowingNoMatches(
                    PushCommand.remoteQuery(key),
                    in: request.repositoryURL
                )
            )
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespacesAndNewlines))
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    /// The one address a Push to `remote` writes to, or a refusal explaining why there is no one
    /// address to confirm.
    ///
    /// Resolved before a confirmation opens rather than left to Git at execution time. A remote
    /// name is not a destination: `.` names this Repository, `remote.<name>.pushurl` may name
    /// several addresses that Git writes to in turn, and neither is visible in an upstream spelled
    /// `origin/main`.
    ///
    /// What is read here is shown and remembered, but a Push is still run by the remote's name.
    /// Pushing to a bare URL would leave the remote-tracking Ref untouched, so what the user sees
    /// afterwards — ahead and behind — would describe work that has already been sent.
    ///
    /// - Throws: `PushDestinationRefusal` for a configuration no single confirmation can describe.
    func destination(_ request: PushDestinationRequest) async throws -> PushDestination {
        guard request.remote != PushCommand.localRemote else {
            throw PushDestinationRefusal.localRepository(remote: request.remote)
        }
        let destinations = try GitPushDestinationParser.parse(
            try await git.data(
                PushCommand.destinationQuery(for: request.remote),
                in: request.repositoryURL
            )
        )
        switch destinations.count {
        case 1:
            let destination = destinations[0]
            // Checked on the address as well as on the name. A remote may be called anything and
            // still be configured to point at `.`, and Git resolves that to the Repository the
            // command runs in whichever of the two spellings led to it.
            guard destination.url != PushCommand.localRemote else {
                throw PushDestinationRefusal.localRepository(remote: request.remote)
            }
            return destination
        case 0:
            // Git answers with at least the fetch URL for every remote that exists, and fails
            // outright for one that does not. Nothing at all is an answer this parser does not
            // understand rather than a remote with nowhere to go.
            throw GitOutputParsingError()
        default:
            throw PushDestinationRefusal.severalDestinations(remote: request.remote, destinations)
        }
    }

    /// Where a Push of `branch` goes and what its upstream holds, or `nil` when the Branch has no
    /// upstream at all.
    func target(_ request: PushTargetRequest) async throws -> PushTarget? {
        guard let target = try GitPushTargetParser.parse(
            try await git.data(
                PushCommand.upstreamQuery(for: request.branch),
                in: request.repositoryURL
            ),
            branch: request.branch
        ) else {
            return nil
        }

        // Read separately, and allowed to answer nothing: an upstream configured for a Branch
        // nobody has fetched yet has no remote-tracking Ref, which is a Push with no lease to take
        // rather than a failure.
        return target.expecting(
            String(
                gitBytes: try await git.dataAllowingNoMatches(
                    PushCommand.objectIDQuery(of: target.trackingRef),
                    in: request.repositoryURL
                )
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
