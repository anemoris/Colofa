////
//  GitBoundedReaderTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The reader is where every Diff limit is actually decided, so the boundaries are exercised
/// against the real thresholds here rather than against a separate copy of the rule.
struct GitBoundedReaderTests {
    private let limits = DiffLimits.standard

    @Test
    func staysWithinTheAutomaticByteLimitBelowItAndExactlyAtIt() async throws {
        let bounds = limits.automaticBounds

        #expect(try await !read(byteCount: bounds.byteCount - 1, bounds: bounds).exceedsBounds)
        #expect(try await !read(byteCount: bounds.byteCount, bounds: bounds).exceedsBounds)
    }

    @Test
    func stopsImmediatelyAboveTheAutomaticByteLimit() async throws {
        let bounds = limits.automaticBounds
        let output = try await read(byteCount: bounds.byteCount + 1, bounds: bounds)

        #expect(output.exceedsBounds)
        // Output Colofa refused is not held on to.
        #expect(output.data.isEmpty)
    }

    @Test
    func staysWithinTheAutomaticLineLimitBelowItAndExactlyAtIt() async throws {
        let bounds = limits.automaticBounds

        #expect(try await !read(lineCount: bounds.lineCount - 1, bounds: bounds).exceedsBounds)
        #expect(try await !read(lineCount: bounds.lineCount, bounds: bounds).exceedsBounds)
    }

    @Test
    func stopsImmediatelyAboveTheAutomaticLineLimit() async throws {
        let bounds = limits.automaticBounds
        let output = try await read(lineCount: bounds.lineCount + 1, bounds: bounds)

        #expect(output.exceedsBounds)
        #expect(output.data.isEmpty)
    }

    @Test
    func staysWithinTheHardByteLimitBelowItAndExactlyAtIt() async throws {
        let bounds = limits.hardBounds

        #expect(try await !read(byteCount: bounds.byteCount - 1, bounds: bounds).exceedsBounds)
        #expect(try await !read(byteCount: bounds.byteCount, bounds: bounds).exceedsBounds)
    }

    @Test
    func stopsImmediatelyAboveTheHardByteLimitWithoutReadingTheRest() async throws {
        let bounds = limits.hardBounds
        // Far past the limit, so a reader that drained its input would report far more.
        let output = try await read(byteCount: bounds.byteCount * 2, bounds: bounds)

        #expect(output.exceedsBounds)
        #expect(output.data.isEmpty)
        #expect(output.byteCount < bounds.byteCount + 128 * 1_024)
    }

    @Test
    func staysWithinTheHardLineLimitBelowItAndExactlyAtIt() async throws {
        let bounds = limits.hardBounds

        #expect(try await !read(lineCount: bounds.lineCount - 1, bounds: bounds).exceedsBounds)
        #expect(try await !read(lineCount: bounds.lineCount, bounds: bounds).exceedsBounds)
    }

    @Test
    func stopsImmediatelyAboveTheHardLineLimit() async throws {
        let bounds = limits.hardBounds
        let output = try await read(lineCount: bounds.lineCount + 1, bounds: bounds)

        #expect(output.exceedsBounds)
        #expect(output.data.isEmpty)
    }

    @Test
    func outputWithoutATrailingNewlineStillEndsInALine() async throws {
        let bounds = GitOutputBounds(byteCount: .max, lineCount: 2)
        let complete = try await read(Data("one\ntwo\n".utf8), bounds: bounds)
        let partial = try await read(Data("one\ntwo\nthree".utf8), bounds: bounds)

        #expect(complete.lineCount == 2)
        #expect(!complete.exceedsBounds)
        #expect(partial.lineCount == 3)
        #expect(partial.exceedsBounds)
    }

    @Test
    func measuringKeepsTheCountsWithoutKeepingTheOutput() async throws {
        let output = try await read(
            Data("one\ntwo\n".utf8),
            bounds: GitOutputBounds(byteCount: .max, lineCount: .max),
            retainsOutput: false
        )

        #expect(output.byteCount == 8)
        #expect(output.lineCount == 2)
        #expect(output.data.isEmpty)
        #expect(!output.exceedsBounds)
    }

    @Test
    func readsNoOutputAsNothing() async throws {
        let output = try await read(Data(), bounds: limits.automaticBounds)

        #expect(output.byteCount == 0)
        #expect(output.lineCount == 0)
        #expect(!output.exceedsBounds)
    }

    /// Exactly `byteCount` bytes on a single line, so only the byte bound can be reached.
    private func read(byteCount: Int, bounds: GitOutputBounds) async throws -> GitBoundedOutput {
        try await read(Data(repeating: UInt8(ascii: "a"), count: byteCount), bounds: bounds)
    }

    /// Exactly `lineCount` newline-terminated lines, kept small enough that only the line bound
    /// can be reached.
    private func read(lineCount: Int, bounds: GitOutputBounds) async throws -> GitBoundedOutput {
        try await read(Data(repeating: UInt8(ascii: "\n"), count: lineCount), bounds: bounds)
    }

    /// Reads from a file rather than a pipe: the reader's own chunking and counting are what is
    /// under test, and a file lets a read that stops early simply leave the rest unread instead
    /// of stranding a writer nobody is draining.
    private func read(
        _ data: Data,
        bounds: GitOutputBounds,
        retainsOutput: Bool = true
    ) async throws -> GitBoundedOutput {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ColofaBoundedRead-\(UUID().uuidString)")
        // Staging failures are the test's own, so they are raised rather than reported as a
        // reader that saw nothing. Removing the fixture afterwards is cleanup, not a result.
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        return try await GitBoundedReader.read(
            from: handle,
            bounds: bounds,
            retainsOutput: retainsOutput
        )
    }
}
