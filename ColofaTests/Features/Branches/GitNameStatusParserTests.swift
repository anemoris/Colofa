////
//  GitNameStatusParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct GitNameStatusParserTests {
    private static func output(_ records: [String]) -> Data {
        Data(records.map { $0 + "\0" }.joined().utf8)
    }

    @Test
    func readsEveryChangedPath() throws {
        let comparison = try GitNameStatusParser.parse(
            Self.output(["M", "changed.swift", "D", "removed.swift", "A", "arriving.swift"])
        )

        #expect(comparison.changedPaths == ["changed.swift", "removed.swift", "arriving.swift"])
        #expect(comparison.addedPaths == ["arriving.swift"])
    }

    /// The NUL-separated form prints paths verbatim, so a path with a space, a quote, or a
    /// non-ASCII character needs no unquoting.
    @Test
    func readsAPathVerbatim() throws {
        let comparison = try GitNameStatusParser.parse(
            Self.output(["M", "partial 文件.txt"])
        )

        #expect(comparison.changedPaths == ["partial 文件.txt"])
    }

    @Test
    func readsNothingFromNoOutput() throws {
        #expect(try GitNameStatusParser.parse(Data()) == .empty)
    }

    /// A refusal must never name paths Colofa did not receive.
    @Test
    func refusesARecordWithoutAPath() {
        #expect(throws: GitOutputParsingError.self) {
            try GitNameStatusParser.parse(Self.output(["M", "changed.swift", "A"]))
        }
    }

    /// An Unborn Branch has nothing to compare against, so every path the Ref holds is one the
    /// Checkout would add.
    @Test
    func treatsEveryPathOfATreeAsArriving() throws {
        let comparison = try GitNameStatusParser.parseTreePaths(
            Self.output(["one.swift", "two.swift"])
        )

        #expect(comparison.changedPaths == ["one.swift", "two.swift"])
        #expect(comparison.addedPaths == comparison.changedPaths)
    }
}
