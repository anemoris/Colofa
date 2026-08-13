////
//  GitReferenceParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct GitReferenceParser {
    nonisolated static func parse(_ data: Data) throws -> RepositoryReferences {
        guard let output = String(data: data, encoding: .utf8) else {
            throw GitOutputParsingError()
        }

        var localBranches: [String] = []
        var remoteBranches: [String] = []
        var tags: [String] = []

        for line in output.split(separator: "\n") {
            let fields = line.split(separator: "\0", omittingEmptySubsequences: false)
            guard fields.count == 2 else { throw GitOutputParsingError() }
            let name = String(fields[0])
            let symbolicTarget = String(fields[1])

            if name.hasPrefix("refs/heads/") {
                localBranches.append(String(name.dropFirst("refs/heads/".count)))
            } else if name.hasPrefix("refs/remotes/"), symbolicTarget.isEmpty {
                remoteBranches.append(String(name.dropFirst("refs/remotes/".count)))
            } else if name.hasPrefix("refs/tags/") {
                tags.append(String(name.dropFirst("refs/tags/".count)))
            } else if !name.hasPrefix("refs/remotes/") {
                throw GitOutputParsingError()
            }
        }

        return RepositoryReferences(
            localBranches: localBranches,
            remoteBranches: remoteBranches,
            tags: tags
        )
    }
}
