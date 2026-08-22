////
//  GitSkipFetchAllParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads which remotes Git's `remote.<name>.skipFetchAll` configuration excludes from a Fetch of
/// every remote.
///
/// The command asks Git for the canonical boolean, so `yes`, `on`, `1`, and a bare key all arrive
/// here as `true` and Colofa never reproduces Git's own rules for reading one.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads this from an actor.
nonisolated enum GitSkipFetchAllParser {
    private static let keyPrefix = "remote."
    private static let keySuffix = ".skipfetchall"

    static func parse(_ data: Data) throws -> Set<String> {
        guard let output = String(data: data, encoding: .utf8) else {
            throw GitOutputParsingError()
        }

        var skipped: Set<String> = []
        for record in output.split(separator: "\0") {
            let fields = record.split(
                separator: "\n",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard fields.count == 2,
                  fields[0].hasPrefix(keyPrefix),
                  fields[0].hasSuffix(keySuffix) else {
                throw GitOutputParsingError()
            }
            let remote = String(
                fields[0].dropFirst(keyPrefix.count).dropLast(keySuffix.count)
            )

            // Git prints one record per scope it read the key in — system, then global, then the
            // Repository — and obeys the last one. A Repository that turns a globally skipped
            // remote back on therefore has to remove it, because leaving the earlier `true`
            // standing would skip a remote Git itself would fetch.
            if fields[1] == "true" {
                skipped.insert(remote)
            } else {
                skipped.remove(remote)
            }
        }
        return skipped
    }
}
