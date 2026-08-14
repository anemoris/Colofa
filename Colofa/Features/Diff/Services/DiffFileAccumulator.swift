////
//  DiffFileAccumulator.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Builds one file's Diff while its patch arrives.
///
/// Paths come from the lines that carry exactly one of them — `rename from`, `rename to`, `---`,
/// `+++`. The `diff --git` header states both on a single line and is therefore ambiguous, so it
/// is used only for the changes that have no other line to state them: binary content and a bare
/// mode change.
nonisolated struct DiffFileAccumulator {
    private let header: String
    private var oldPath: String?
    private var newPath: String?
    private var hasStatedPaths = false
    private var oldMode: String?
    private var newMode: String?
    private var isBinary = false
    private var hunks: [DiffHunk] = []
    private var hunk: DiffHunkAccumulator?

    /// - Parameter header: The `diff --git` line with its command prefix removed.
    init(header: String) {
        self.header = header
    }

    mutating func consume(_ line: String) throws {
        if line.hasPrefix("@@") {
            closeHunk()
            hunk = try DiffHunkAccumulator(id: hunks.count, header: line)
            return
        }
        if hunk != nil, DiffHunkAccumulator.isContent(line) {
            hunk?.append(line)
            return
        }
        closeHunk()
        consumeHeaderLine(line)
    }

    func build() -> DiffFile {
        let paths = hasStatedPaths
            ? (old: oldPath, new: newPath)
            : Self.paths(inHeader: header)
        return DiffFile(
            oldPath: paths.old,
            newPath: paths.new,
            oldMode: oldMode,
            newMode: newMode,
            content: content(hunk.map { hunks + [$0.build()] } ?? hunks)
        )
    }

    private func content(_ hunks: [DiffHunk]) -> DiffFile.Content {
        if isBinary {
            return .binary
        }
        guard oldMode == Self.submoduleMode || newMode == Self.submoduleMode else {
            return .text(hunks)
        }
        // A submodule's patch says only which Commit each side pointed at, and those two IDs are
        // the change: rendering them as added and removed lines of prose would be theatre.
        let lines = hunks.flatMap(\.lines)
        return .submodule(
            oldCommitID: Self.submoduleCommitID(in: lines, kind: .deletion),
            newCommitID: Self.submoduleCommitID(in: lines, kind: .addition)
        )
    }

    private mutating func consumeHeaderLine(_ line: String) {
        if let prefix = Self.oldPathPrefixes.first(where: line.hasPrefix) {
            oldPath = Self.statedPath(in: line, after: prefix)
            hasStatedPaths = true
        } else if let prefix = Self.newPathPrefixes.first(where: line.hasPrefix) {
            newPath = Self.statedPath(in: line, after: prefix)
            hasStatedPaths = true
        } else if line.hasPrefix("Binary files ") || line.hasPrefix("GIT binary patch") {
            isBinary = true
        } else {
            consumeModeLine(line)
        }
    }

    private mutating func consumeModeLine(_ line: String) {
        if let mode = Self.value(in: line, after: "old mode ") {
            oldMode = mode
        } else if let mode = Self.value(in: line, after: "new mode ") {
            newMode = mode
        } else if let mode = Self.value(in: line, after: "new file mode ") {
            newMode = mode
        } else if let mode = Self.value(in: line, after: "deleted file mode ") {
            oldMode = mode
        } else if let fields = Self.value(in: line, after: "index ")?.split(separator: " "),
                  fields.count == 2 {
            // `index <old>..<new> <mode>` states a mode only when it did not change.
            oldMode = oldMode ?? String(fields[1])
            newMode = newMode ?? String(fields[1])
        }
    }

    private mutating func closeHunk() {
        guard let hunk else {
            return
        }
        hunks.append(hunk.build())
        self.hunk = nil
    }

    private static let submoduleMode = "160000"

    private static let oldPathPrefixes = ["--- ", "rename from "]
    private static let newPathPrefixes = ["+++ ", "rename to "]

    private static func value(in line: String, after prefix: String) -> String? {
        guard line.hasPrefix(prefix) else {
            return nil
        }
        return String(line.dropFirst(prefix.count))
    }

    /// A path the patch states on its own line. `/dev/null` names the side that has no file, so
    /// it is a stated absence rather than a missing statement.
    ///
    /// A `---` or `+++` marker for a path containing a space ends in a tab, which is how the
    /// unified format separates the name from the timestamp field Git leaves empty. An unquoted
    /// path can never contain a tab itself — Git quotes one that does — so the first tab always
    /// ends the name.
    private static func statedPath(in line: String, after prefix: String) -> String? {
        let value = String(line.dropFirst(prefix.count))
        let path = GitQuotedPath.splitQuoted(value).map(\.quoted)
            ?? String(value.prefix { $0 != "\t" })
        return path == "/dev/null" ? nil : strippingSidePrefix(path)
    }

    private static func submoduleCommitID(
        in lines: [DiffLine],
        kind: DiffLine.Kind
    ) -> String? {
        let marker = "Subproject commit "
        return lines.first { $0.kind == kind && $0.text.hasPrefix(marker) }
            .map { String($0.text.dropFirst(marker.count)) }
    }

    /// Splits `a/<old> b/<new>` back into two paths.
    ///
    /// Halves of equal length are preferred because the changes that need this header — binary
    /// content and a bare mode change — keep one path, so an inner space belongs to the path
    /// rather than separating the two.
    private static func paths(inHeader header: String) -> (old: String?, new: String?) {
        if let split = GitQuotedPath.splitQuoted(header) {
            return (
                strippingSidePrefix(split.quoted),
                strippingSidePrefix(GitQuotedPath.decoded(split.remainder))
            )
        }

        let candidates = header.indices
            .filter { header[$0] == " " }
            .map { space in
                (
                    String(header[header.startIndex..<space]),
                    String(header[header.index(after: space)...])
                )
            }
            .filter { $0.0.hasPrefix("a/") && $0.1.hasPrefix("b/") }
        guard let chosen = candidates.first(where: { $0.0.count == $0.1.count })
            ?? candidates.first else {
            return (nil, nil)
        }
        return (strippingSidePrefix(chosen.0), strippingSidePrefix(chosen.1))
    }

    private static func strippingSidePrefix(_ path: String) -> String {
        path.hasPrefix("a/") || path.hasPrefix("b/") ? String(path.dropFirst(2)) : path
    }
}
