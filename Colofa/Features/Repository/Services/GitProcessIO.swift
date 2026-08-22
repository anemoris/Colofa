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

    /// Drains one of a process's output pipes, keeping at most `limit` bytes of what it read.
    ///
    /// Reading is what lets Git finish: a pipe nobody empties fills at the operating system's
    /// buffer size, and Git then blocks writing into it forever. Both of a command's pipes are
    /// therefore drained at the same time, and neither reader may stall the other — which is why
    /// this reads chunks off a `GitPipeChannel` rather than iterating `FileHandle.bytes`. Per-byte
    /// async iteration was measured to run one pipe at a time: the reader waiting on a silent
    /// standard error held up the one draining standard output until Git filled that pipe and
    /// stopped, and neither ever finished.
    ///
    /// `limit` bounds what is kept, never what is read. Output past it is dropped as it arrives:
    /// a caller that only needs the first few thousand bytes of a diagnostic still has to let
    /// Git write the rest.
    ///
    /// Ending Git usually ends the read with it, but not always: a Git that left a child of its
    /// own behind leaves that child holding the pipe open, and the read would then outlive the
    /// Cancel by as long as the child lives. Cancellation therefore stops the channel, which ends
    /// the read without waiting for anyone to close the pipe.
    static func readData(from handle: FileHandle, limit: Int?) async throws -> Data {
        let channel = try GitPipeChannel(reading: handle)

        return try await withTaskCancellationHandler {
            var output = Data()
            do {
                for try await chunk in channel.chunks {
                    guard let limit else {
                        output.append(chunk)
                        continue
                    }
                    if output.count < limit {
                        output.append(chunk.prefix(limit - output.count))
                    }
                }
            } catch {
                try Task.checkCancellation()
                throw error
            }
            // A stopped channel ends the read the same way the end of the output does, so a read
            // that came back while cancelled came back short — whether it ended with an error or
            // with the bytes that had already arrived. Both are reported as the Cancel they were,
            // because part of an answer must never be readable as the whole of one.
            try Task.checkCancellation()
            return output
        } onCancel: {
            channel.stop()
        }
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
