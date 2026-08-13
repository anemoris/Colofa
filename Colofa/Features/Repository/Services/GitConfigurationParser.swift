////
//  GitConfigurationParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

enum GitConfigurationParser {
    nonisolated static func parse(_ data: Data) throws -> GitConfigurationSnapshot {
        let records = data.split(separator: 0, omittingEmptySubsequences: true)
        guard records.count.isMultiple(of: 3) else {
            throw GitOutputParsingError()
        }

        var entries = [GitConfigurationEntry]()
        entries.reserveCapacity(records.count / 3)

        for index in stride(from: 0, to: records.count, by: 3) {
            guard let scope = String(bytes: records[index], encoding: .utf8),
                  let origin = String(bytes: records[index + 1], encoding: .utf8) else {
                throw GitOutputParsingError()
            }
            let (key, value) = try keyAndValue(in: records[index + 2])
            guard let configurationKey = GitConfigurationKey(rawValue: key) else {
                continue
            }
            entries.append(
                GitConfigurationEntry(
                    key: configurationKey,
                    value: value,
                    scope: GitConfigurationScope(rawValue: scope),
                    origin: GitConfigurationOrigin(rawValue: origin)
                )
            )
        }

        return GitConfigurationSnapshot(entries: entries)
    }

    /// Splits one `--null` record into its key and value.
    ///
    /// Git writes `key\nvalue` for a configured value, but a key declared without `=` has no
    /// value line at all and arrives as a bare key. Git treats that as an implicit boolean, so
    /// it is reported as an empty value rather than failing the whole repository load.
    private nonisolated static func keyAndValue(in record: Data) throws -> (String, String) {
        guard let separator = record.firstIndex(of: 0x0A) else {
            guard let key = String(bytes: record, encoding: .utf8) else {
                throw GitOutputParsingError()
            }
            return (key, "")
        }

        guard let key = String(bytes: record[..<separator], encoding: .utf8),
              let value = String(bytes: record[record.index(after: separator)...], encoding: .utf8) else {
            throw GitOutputParsingError()
        }
        return (key, value)
    }
}
