////
//  GitBoundedReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads a Git command's standard output while counting it, and stops the moment it passes the
/// bounds it was given.
///
/// It reads in chunks on a thread of its own: a bounded read has to see the size of the output
/// before deciding anything, and per-byte async iteration cannot keep up with a patch measured in
/// megabytes. Output that crosses a bound is dropped rather than returned, because the point of
/// stopping is not to hold what Colofa has already refused.
nonisolated enum GitBoundedReader {
    /// - Throws: whatever reading failed with. A failed read must not be reported as the end of
    ///   the output: a patch cut short by an I/O error would otherwise be rendered as a complete
    ///   one, which is the one thing a Diff may never be.
    static func read(
        from handle: FileHandle,
        bounds: GitOutputBounds,
        retainsOutput: Bool
    ) async throws -> GitBoundedOutput {
        try await Task.detached {
            var data = Data()
            var byteCount = 0
            var newlineCount = 0
            var endsWithNewline = true

            while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
                byteCount += chunk.count
                newlineCount += chunk.count(where: { $0 == UInt8(ascii: "\n") })
                endsWithNewline = chunk.last == UInt8(ascii: "\n")
                if retainsOutput {
                    data.append(chunk)
                }
                guard byteCount <= bounds.byteCount, newlineCount <= bounds.lineCount else {
                    return GitBoundedOutput(
                        data: Data(),
                        byteCount: byteCount,
                        lineCount: newlineCount,
                        exceedsBounds: true
                    )
                }
            }

            // Output that does not end in a newline still ends in a line.
            let lineCount = newlineCount + (byteCount > 0 && !endsWithNewline ? 1 : 0)
            let exceedsBounds = lineCount > bounds.lineCount
            return GitBoundedOutput(
                data: exceedsBounds ? Data() : data,
                byteCount: byteCount,
                lineCount: lineCount,
                exceedsBounds: exceedsBounds
            )
        }.value
    }

    private static let chunkSize = 64 * 1_024
}
