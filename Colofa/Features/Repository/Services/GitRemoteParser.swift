////
//  GitRemoteParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct GitRemoteParser {
    nonisolated static func parse(_ data: Data) throws -> [RepositoryRemote] {
        try data.split(separator: 0).map { record in
            guard let value = String(data: Data(record), encoding: .utf8) else {
                throw GitOutputParsingError()
            }
            let fields = value.split(separator: "\n", maxSplits: 1)
            guard fields.count == 2,
                  fields[0].hasPrefix("remote."),
                  fields[0].hasSuffix(".url") else {
                throw GitOutputParsingError()
            }
            return RepositoryRemote(
                name: String(fields[0].dropFirst("remote.".count).dropLast(".url".count)),
                url: String(fields[1])
            )
        }
        .reduce(into: []) { remotes, remote in
            if !remotes.contains(where: { $0.name == remote.name }) {
                remotes.append(remote)
            }
        }
        .sorted { $0.name < $1.name }
    }
}
