////
//  GitTagReferenceParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads tag names and the objects they point at, from the remote and from the Repository.
///
/// Both sides report the tag ref's own object, so an annotated tag is compared as the tag object
/// it is rather than as the Commit it happens to peel to.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads these from an actor.
nonisolated enum GitTagReferenceParser {
    private static let tagPrefix = "refs/tags/"

    /// `git ls-remote --tags --refs`, which reports one tab-separated record per line.
    static func parseRemote(_ data: Data) throws -> [String: String] {
        try parse(data, recordSeparator: "\n", fieldSeparator: "\t")
    }

    /// `git for-each-ref` over `refs/tags`, whose format puts a NUL between the two fields.
    static func parseLocal(_ data: Data) throws -> [String: String] {
        try parse(data, recordSeparator: "\n", fieldSeparator: "\0")
    }

    private static func parse(
        _ data: Data,
        recordSeparator: Character,
        fieldSeparator: Character
    ) throws -> [String: String] {
        guard let output = String(data: data, encoding: .utf8) else {
            throw GitOutputParsingError()
        }

        var tags: [String: String] = [:]
        for record in output.split(separator: recordSeparator) {
            let fields = record.split(
                separator: fieldSeparator,
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard fields.count == 2, fields[1].hasPrefix(tagPrefix) else {
                throw GitOutputParsingError()
            }
            tags[String(fields[1].dropFirst(tagPrefix.count))] = String(fields[0])
        }
        return tags
    }
}
