////
//  GitPushTargetParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads where a Push of one Branch goes, out of Git's own answer about that Branch's upstream.
///
/// The Ref is checked rather than trusted. `for-each-ref` matches a literal pattern completely or
/// up to a slash, so asking about `refs/heads/feature` also reports `refs/heads/feature/work` —
/// and pushing the wrong Branch because a longer one happened to sort first is exactly the kind of
/// mistake this whole path exists to prevent.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads this from an actor.
nonisolated enum GitPushTargetParser {

    /// Where a Push of `branch` goes, or `nil` when the Branch has no upstream — which is the
    /// state Publish answers rather than Push.
    ///
    /// The expected object is deliberately absent here: this reads configuration, and only a read
    /// of the remote-tracking Ref itself can say what is at the other end right now.
    static func parse(_ data: Data, branch: String) throws -> PushTarget? {
        guard let output = String(data: data, encoding: .utf8) else {
            throw GitOutputParsingError()
        }

        let branchRef = PushCommand.headRef(branch)
        for record in output.split(separator: "\n") {
            let fields = record.split(separator: "\0", omittingEmptySubsequences: false)
            guard fields.count == 5 else {
                throw GitOutputParsingError()
            }
            guard fields[0] == branchRef else {
                continue
            }
            // Every upstream field is empty together: a Branch either has one or does not, and a
            // half-answer would mean Git reported something this parser does not understand.
            guard !fields[1].isEmpty, !fields[2].isEmpty, !fields[3].isEmpty, !fields[4].isEmpty else {
                return nil
            }
            return PushTarget(
                remote: String(fields[1]),
                remoteRef: String(fields[2]),
                upstream: String(fields[3]),
                trackingRef: String(fields[4])
            )
        }
        return nil
    }
}
