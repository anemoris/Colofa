////
//  HistoryParsingPerformanceTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest
@testable import Colofa

/// Parsing is the work a page bound exists to keep small, so it is measured at the page History
/// actually asks for: two hundred Commits, plus the extra record that answers Load More.
///
/// `XCTest` rather than Swift Testing because `measure` has no equivalent there yet.
///
/// Declared `nonisolated` because the target defaults to Main Actor isolation, which `XCTestCase`
/// initializers do not adopt.
nonisolated final class HistoryParsingPerformanceTests: XCTestCase {
    func testParsesAFullPageOfCommits() {
        let output = Self.output(commitCount: 201)

        measure {
            let commits = try? GitHistoryParser.parse(output, remoteBranchNames: ["origin/main"])
            XCTAssertEqual(commits?.count, 201)
        }
    }

    /// Every record carries a decoration, which is the shape that gives the parser the most Ref
    /// classification to do.
    private static func output(commitCount: Int) -> Data {
        var records = ""
        for index in 0..<commitCount {
            let objectID = String(repeating: "0", count: 33) + String(1_000_000 + index)
            let fields = [
                objectID,
                String(objectID.prefix(7)),
                objectID,
                "Colofa Tests",
                "colofa-tests@example.invalid",
                "1700000000",
                "Colofa Tests",
                "colofa-tests@example.invalid",
                "1700000060",
                "HEAD -> main, tag: v\(index), origin/main",
                "Fixture commit \(index)",
            ]
            records += "\u{1e}" + fields.joined(separator: "\u{0}") + "\n"
        }
        return Data(records.utf8)
    }
}
