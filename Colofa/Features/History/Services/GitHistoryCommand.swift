////
//  GitHistoryCommand.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The Git invocations behind History, kept as values so the argument lists are testable without
/// launching anything.
///
/// Every configuration a Repository could otherwise decide for Colofa is stated: colour,
/// signature verification, and notes each append output that is not part of the record being
/// parsed, and any of them would turn a readable page into a parsing failure.
nonisolated struct GitHistoryCommand: Equatable, Sendable {
    let arguments: [String]

    /// One page of reachable Commits.
    ///
    /// One record more than the page is asked for, and dropped, so Load More is offered because
    /// Git reported something further rather than because the page happened to come back full.
    static func page(for request: HistoryPageRequest) -> Self {
        Self(
            arguments: logPrefix
                + (request.scope == .firstParent ? ["--first-parent"] : [])
                + [
                    "--topo-order",
                    "--max-count=\(request.pageSize + 1)",
                    "--skip=\(request.offset)",
                    "--format=\(recordFormat)",
                    request.reference.revision,
                    "--",
                ]
        )
    }

    /// The selected Commit's message, byte for byte.
    static func message(for objectID: String) -> Self {
        Self(arguments: logPrefix + ["--max-count=1", "--format=%B", objectID, "--"])
    }

    /// A record separator no Git identity, subject, or decoration can contain, followed by
    /// NUL-separated fields. `-z` is not used: it would separate Commits with the same byte that
    /// separates fields.
    ///
    /// Times are read as UNIX timestamps rather than as formatted dates, so no Repository
    /// setting, locale, or parser stands between Git and the value.
    static let recordFormat = [
        "%x1e%H", "%h", "%P", "%an", "%ae", "%at", "%cn", "%ce", "%ct", "%D", "%s",
    ].joined(separator: "%x00")

    private static let logPrefix = [
        "--no-optional-locks", "log", "--no-color", "--no-show-signature", "--no-notes",
    ]
}
