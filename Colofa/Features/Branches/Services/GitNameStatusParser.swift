////
//  GitNameStatusParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads `git diff --name-status -z --no-renames`, which reports what one revision changes
/// relative to another without writing any patch out.
///
/// The NUL-separated form prints paths verbatim, so no path needs unquoting and none can be
/// misread. Rename detection is off deliberately: a Checkout is refused per path, and a rename
/// reported as one record would hide one of the two paths it touches.
nonisolated enum GitNameStatusParser {
    /// - Throws: `GitOutputParsingError` for a record Colofa cannot read, so a refusal never
    ///   names paths it did not receive.
    static func parse(_ data: Data) throws -> CheckoutComparison {
        var changedPaths: Set<String> = []
        var addedPaths: Set<String> = []
        let records = data.split(separator: 0).map(String.init(gitBytes:))

        var index = 0
        while index < records.count {
            let status = records[index]
            guard index + 1 < records.count, let letter = status.first else {
                throw GitOutputParsingError()
            }
            let path = records[index + 1]
            changedPaths.insert(path)
            if letter == "A" {
                addedPaths.insert(path)
            }
            index += 2
        }

        return CheckoutComparison(changedPaths: changedPaths, addedPaths: addedPaths)
    }

    /// Reads `git ls-tree -r --name-only -z`, which is what an Unborn Branch has to be compared
    /// against: every path the target Ref holds is one the Checkout would add.
    static func parseTreePaths(_ data: Data) throws -> CheckoutComparison {
        let paths = Set(data.split(separator: 0).map(String.init(gitBytes:)))
        guard !paths.contains("") else {
            throw GitOutputParsingError()
        }
        return CheckoutComparison(changedPaths: paths, addedPaths: paths)
    }
}
