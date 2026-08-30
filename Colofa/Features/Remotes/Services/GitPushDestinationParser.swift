////
//  GitPushDestinationParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads every address one Push to a remote would write to, out of Git's own answer.
///
/// Git reports one address per line and reports several whenever `remote.<name>.pushurl` names
/// several, which is the whole reason this is read at all: the count is what decides whether the
/// destination can be confirmed.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads this from an actor.
nonisolated enum GitPushDestinationParser {
    static func parse(_ data: Data) throws -> [PushDestination] {
        guard let output = String(data: data, encoding: .utf8) else {
            throw GitOutputParsingError()
        }
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map(PushDestination.init)
    }
}
