////
//  DiffNumstatParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct DiffNumstatParserTests {
    @Test
    func parsesCountsBinaryChangesAndRenames() throws {
        let output = [
            "18\t4\tSources/App.swift",
            "-\t-\tArt/logo.png",
            "3\t3\t",
            "old 名称.txt",
            "new 名称.txt",
            "",
        ].joined(separator: "\0")

        let summaries = try DiffNumstatParser.parse(Data(output.utf8))

        #expect(summaries.count == 3)
        #expect(summaries[0].newPath == "Sources/App.swift")
        #expect(summaries[0].oldPath == nil)
        #expect(summaries[0].stats == DiffStats(additions: 18, deletions: 4))
        #expect(summaries[1].isBinary)
        #expect(summaries[1].stats == nil)
        #expect(summaries[2].oldPath == "old 名称.txt")
        #expect(summaries[2].newPath == "new 名称.txt")
        #expect(summaries[2].isRenamed)
    }

    @Test
    func summaryTotalsIgnoreTheBinaryChangeThatHasNoCounts() throws {
        let output = ["4\t1\ta.txt", "-\t-\tb.bin", ""].joined(separator: "\0")

        let summary = DiffSummary(
            files: try DiffNumstatParser.parse(Data(output.utf8)),
            measurement: DiffMeasurement(byteCount: 1, lineCount: 1, isComplete: true)
        )

        #expect(summary.stats == DiffStats(additions: 4, deletions: 1))
    }

    @Test
    func readsNoOutputAsNoFiles() throws {
        #expect(try DiffNumstatParser.parse(Data()).isEmpty)
    }

    @Test
    func refusesRecordsItCannotRead() {
        #expect(throws: GitOutputParsingError.self) {
            try DiffNumstatParser.parse(Data("18\tSources/App.swift\0".utf8))
        }
        #expect(throws: GitOutputParsingError.self) {
            try DiffNumstatParser.parse(Data("x\t4\tSources/App.swift\0".utf8))
        }
        // A rename record that never states its two paths.
        #expect(throws: GitOutputParsingError.self) {
            try DiffNumstatParser.parse(Data("3\t3\t\0old.txt\0".utf8))
        }
    }
}
