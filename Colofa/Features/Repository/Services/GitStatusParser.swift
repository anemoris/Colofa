////
//  GitStatusParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct GitStatusParser {
    nonisolated static func parse(_ data: Data) throws -> RepositoryStatus {
        let records = try data.split(separator: 0).map(decode)
        var headers: [String: String] = [:]
        var stagedChanges: [RepositoryChange] = []
        var unstagedChanges: [RepositoryChange] = []
        var index = 0

        while index < records.count {
            let record = records[index]
            if record.hasPrefix("# ") {
                let header = record.dropFirst(2).split(separator: " ", maxSplits: 1)
                guard header.count == 2 else { throw GitOutputParsingError() }
                headers[String(header[0])] = String(header[1])
            } else if record.hasPrefix("1 ") {
                let fields = record.split(separator: " ", maxSplits: 8)
                guard fields.count == 9 else { throw GitOutputParsingError() }
                try appendChanges(
                    status: fields[1],
                    path: String(fields[8]),
                    originalPath: nil,
                    staged: &stagedChanges,
                    unstaged: &unstagedChanges
                )
            } else if record.hasPrefix("2 ") {
                let fields = record.split(separator: " ", maxSplits: 9)
                guard fields.count == 10, index + 1 < records.count else {
                    throw GitOutputParsingError()
                }
                index += 1
                try appendChanges(
                    status: fields[1],
                    path: String(fields[9]),
                    originalPath: records[index],
                    staged: &stagedChanges,
                    unstaged: &unstagedChanges
                )
            } else if record.hasPrefix("u ") {
                let fields = record.split(separator: " ", maxSplits: 10)
                guard fields.count == 11 else { throw GitOutputParsingError() }
                unstagedChanges.append(
                    RepositoryChange(path: String(fields[10]), kind: .conflict)
                )
            } else if record.hasPrefix("? ") {
                unstagedChanges.append(
                    RepositoryChange(path: String(record.dropFirst(2)), kind: .untracked)
                )
            } else if !record.hasPrefix("! ") {
                throw GitOutputParsingError()
            }
            index += 1
        }

        guard let oid = headers["branch.oid"],
              let branch = headers["branch.head"] else {
            throw GitOutputParsingError()
        }

        return RepositoryStatus(
            head: head(oid: oid, branch: branch),
            upstream: try upstream(from: headers),
            stagedChanges: stagedChanges.sorted(by: changeOrder),
            unstagedChanges: unstagedChanges.sorted(by: changeOrder)
        )
    }

    private nonisolated static func decode(_ data: Data.SubSequence) throws -> String {
        guard let value = String(data: Data(data), encoding: .utf8) else {
            throw GitOutputParsingError()
        }
        return value
    }

    private nonisolated static func appendChanges(
        status: Substring,
        path: String,
        originalPath: String?,
        staged: inout [RepositoryChange],
        unstaged: inout [RepositoryChange]
    ) throws {
        guard status.count == 2 else { throw GitOutputParsingError() }
        let values = Array(status)

        if let kind = try kind(for: values[0], originalPath: originalPath) {
            staged.append(RepositoryChange(path: path, kind: kind))
        }
        if let kind = try kind(for: values[1], originalPath: originalPath) {
            unstaged.append(RepositoryChange(path: path, kind: kind))
        }
    }

    private nonisolated static func kind(
        for status: Character,
        originalPath: String?
    ) throws -> RepositoryChangeKind? {
        switch status {
        case ".": return nil
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "T": return .typeChanged
        case "R", "C":
            guard let originalPath else { throw GitOutputParsingError() }
            return .renamed(from: originalPath)
        case "U": return .conflict
        default: throw GitOutputParsingError()
        }
    }

    private nonisolated static func head(oid: String, branch: String) -> RepositoryHead {
        if oid == "(initial)" {
            return .unbornBranch(branch)
        }
        if branch == "(detached)" {
            return .detached(oid)
        }
        return .branch(branch)
    }

    private nonisolated static func upstream(
        from headers: [String: String]
    ) throws -> RepositoryUpstream? {
        guard let name = headers["branch.upstream"] else { return nil }
        guard let countHeader = headers["branch.ab"] else {
            return RepositoryUpstream(name: name, ahead: 0, behind: 0)
        }
        let counts = countHeader.split(separator: " ")
        guard counts.count == 2,
              counts[0].first == "+",
              counts[1].first == "-",
              let ahead = Int(counts[0].dropFirst()),
              let behind = Int(counts[1].dropFirst()) else {
            throw GitOutputParsingError()
        }
        return RepositoryUpstream(name: name, ahead: ahead, behind: behind)
    }

    private nonisolated static func changeOrder(
        _ lhs: RepositoryChange,
        _ rhs: RepositoryChange
    ) -> Bool {
        let lhsIsConflict = isConflict(lhs.kind)
        let rhsIsConflict = isConflict(rhs.kind)
        if lhsIsConflict != rhsIsConflict {
            return lhsIsConflict
        }
        return lhs.path < rhs.path
    }

    private nonisolated static func isConflict(_ kind: RepositoryChangeKind) -> Bool {
        if case .conflict = kind {
            return true
        }
        return false
    }
}
