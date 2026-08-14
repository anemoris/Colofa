////
//  GitProcessIO.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reading from, writing to, and waiting on a running Git process.
///
/// Separate from `GitProcess`, which decides what to run and what a failure means; these only
/// move bytes and report what a process did.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: this work must
/// stay off the main actor.
nonisolated enum GitProcessIO {
    static func diagnostic(errorOutput: Data, output: Data) -> String {
        [errorOutput, output]
            .map { String(gitBytes: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    static func readData(from handle: FileHandle, limit: Int?) async throws -> Data {
        var output = Data()
        for try await byte in handle.bytes where output.count < (limit ?? .max) {
            output.append(byte)
        }
        return output
    }

    /// Feeds `text` to the process and closes the pipe, which is what tells Git the input ended.
    ///
    /// A failed write is not reported separately: Git then sees a short or empty input and fails
    /// with its own message, which is the failure the user needs to read.
    static func write(_ text: String, to handle: FileHandle) {
        defer { try? handle.close() }
        try? handle.write(contentsOf: Data(text.utf8))
    }

    static func waitForTermination(of process: Process) async -> Int32 {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { process in
                    continuation.resume(returning: process.terminationStatus)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}
