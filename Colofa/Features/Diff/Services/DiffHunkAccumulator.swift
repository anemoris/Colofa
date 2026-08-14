////
//  DiffHunkAccumulator.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Builds one Hunk while its lines arrive, assigning each line the numbers Git implies rather
/// than states: a patch prints ranges once and then expects the reader to count.
nonisolated struct DiffHunkAccumulator {
    private let id: Int
    private let oldStart: Int
    private let oldCount: Int
    private let newStart: Int
    private let newCount: Int
    private let heading: String
    private var lines: [DiffLine] = []
    private var oldNumber: Int
    private var newNumber: Int

    /// Parses a `@@ -old,count +new,count @@ heading` line.
    ///
    /// - Throws: `GitOutputParsingError` for a header Colofa cannot read as a two-sided patch,
    ///   including the `@@@` header of a combined Diff, which describes several parents at once.
    init(id: Int, header: String) throws {
        guard header.hasPrefix("@@ ") else {
            throw GitOutputParsingError()
        }
        let start = header.index(header.startIndex, offsetBy: 2)
        guard let end = header.range(of: "@@", range: start..<header.endIndex) else {
            throw GitOutputParsingError()
        }

        let ranges = header[start..<end.lowerBound].split(separator: " ")
        guard ranges.count == 2,
              let old = Self.range(ranges[0], marker: "-"),
              let new = Self.range(ranges[1], marker: "+") else {
            throw GitOutputParsingError()
        }

        self.id = id
        oldStart = old.start
        oldCount = old.count
        newStart = new.start
        newCount = new.count
        heading = String(header[end.upperBound...].drop { $0 == " " })
        oldNumber = old.start
        newNumber = new.start
    }

    /// Whether `line` is content of this Hunk rather than the start of the next header.
    static func isContent(_ line: String) -> Bool {
        guard let first = line.first else {
            // Some producers drop the marker from an otherwise empty context line.
            return true
        }
        return first == " " || first == "+" || first == "-" || first == "\\"
    }

    mutating func append(_ line: String) {
        let text = String(line.dropFirst())
        switch line.first {
        case "+":
            appendLine(kind: .addition, oldNumber: nil, newNumber: newNumber, text: text)
            newNumber += 1
        case "-":
            appendLine(kind: .deletion, oldNumber: oldNumber, newNumber: nil, text: text)
            oldNumber += 1
        case "\\":
            // Git's own wording for the missing final newline is replaced by Colofa's, which is
            // localized; the fact it carries is that the line above it ends the file.
            appendLine(kind: .noNewlineMarker, oldNumber: nil, newNumber: nil, text: "")
        default:
            appendLine(kind: .context, oldNumber: oldNumber, newNumber: newNumber, text: text)
            oldNumber += 1
            newNumber += 1
        }
    }

    func build() -> DiffHunk {
        DiffHunk(
            id: id,
            oldStart: oldStart,
            oldCount: oldCount,
            newStart: newStart,
            newCount: newCount,
            heading: heading,
            lines: lines
        )
    }

    private mutating func appendLine(
        kind: DiffLine.Kind,
        oldNumber: Int?,
        newNumber: Int?,
        text: String
    ) {
        lines.append(
            DiffLine(
                id: lines.count,
                kind: kind,
                oldNumber: oldNumber,
                newNumber: newNumber,
                text: text
            )
        )
    }

    /// A range Git abbreviates to a single number covers exactly one line.
    private static func range(
        _ field: Substring,
        marker: Character
    ) -> (start: Int, count: Int)? {
        guard field.first == marker else {
            return nil
        }
        let numbers = field.dropFirst().split(separator: ",")
        guard let start = Int(numbers.first ?? "") else {
            return nil
        }
        switch numbers.count {
        case 1: return (start, 1)
        case 2: return Int(numbers[1]).map { (start, $0) }
        default: return nil
        }
    }
}
