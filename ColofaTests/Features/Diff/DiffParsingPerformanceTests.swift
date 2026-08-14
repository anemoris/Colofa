////
//  DiffParsingPerformanceTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest
@testable import Colofa

/// Parsing is the work a Diff limit exists to bound, so it is measured at the largest patch the
/// limits allow: a confirmed read of 100,000 lines.
///
/// `XCTest` rather than Swift Testing because `measure` has no equivalent there yet.
///
/// Declared `nonisolated` because the target defaults to Main Actor isolation, which `XCTestCase`
/// initializers do not adopt.
nonisolated final class DiffParsingPerformanceTests: XCTestCase {
    func testParsesAConfirmedHundredThousandLinePatch() {
        let patch = Self.patch(lineCount: 100_000)

        measure {
            let files = try? DiffPatchParser.parse(patch)
            XCTAssertEqual(files?.first?.hunks.first?.lines.count, 100_000 - 5)
        }
    }

    /// Both layouts are built while parsing, so regrouping a patch this size is part of what is
    /// being measured here.
    func testBuildsSplitRowsForAHundredThousandLines() {
        guard let file = try? DiffPatchParser.parse(Self.patch(lineCount: 100_000)).first,
              let hunk = file.hunks.first else {
            return XCTFail("The staged patch did not parse")
        }

        measure {
            XCTAssertFalse(DiffSplitRow.rows(from: hunk.lines).isEmpty)
        }
    }

    /// A patch of alternating replacements and context, which is the shape that gives the Split
    /// layout the most pairing to do.
    private static func patch(lineCount: Int) -> Data {
        var patch = """
        diff --git a/large.txt b/large.txt
        index 1111111..2222222 100644
        --- a/large.txt
        +++ b/large.txt
        @@ -1,\(lineCount) +1,\(lineCount) @@

        """
        for line in 0..<(lineCount - 5) {
            switch line % 3 {
            case 0: patch += " context line \(line)\n"
            case 1: patch += "-removed line \(line)\n"
            default: patch += "+added line \(line)\n"
            }
        }
        return Data(patch.utf8)
    }
}
