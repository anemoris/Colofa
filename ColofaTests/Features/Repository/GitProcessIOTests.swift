////
//  GitProcessIOTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Foundation
import Testing
@testable import Colofa

/// Draining a process's two pipes at once, which is the one thing these reads have to get right.
///
/// A pipe stops accepting writes once the operating system's buffer is full, so a writer with
/// more to say blocks until a reader empties it. The reads below therefore write past that buffer
/// while a second pipe stays silent — the shape of a Git command that answers on standard output
/// and says nothing on standard error — and the last one covers the other way a read ends, which
/// is Colofa abandoning it. Each carries a time limit because the failure this guards against is
/// a read that never returns, and a suite that hangs reports nothing at all.
struct GitProcessIOTests {
    /// Comfortably past the 64 KiB a pipe holds on macOS.
    private static let payload = Data(repeating: UInt8(ascii: "a"), count: 256 * 1_024)

    @Test(.timeLimit(.minutes(1)))
    func readsOutputLargerThanThePipeBufferWhileTheOtherPipeStaysSilent() async throws {
        let pipes = try await readBothPipes(limit: nil)

        #expect(pipes.output == Self.payload)
        #expect(pipes.errorOutput.isEmpty)
    }

    /// The limit bounds what is kept, not what is read: a reader that stopped at it would leave
    /// the rest of the output in the pipe and the writer blocked on it forever.
    @Test(.timeLimit(.minutes(1)))
    func keepsOnlyTheLimitWhileStillReadingPastIt() async throws {
        let pipes = try await readBothPipes(limit: 4_000)

        #expect(pipes.output == Self.payload.prefix(4_000))
    }

    @Test(.timeLimit(.minutes(1)))
    func readsOutputThatEndsBeforeTheLimit() async throws {
        let pipes = try await readBothPipes(limit: Self.payload.count * 2)

        #expect(pipes.output == Self.payload)
    }

    /// Cancelling has to return the read even when nothing will ever close the pipe.
    ///
    /// The writer here stays open for the whole test, so nothing but cancellation can end the
    /// read. Ending the command would not be enough either — a command that left a child of its
    /// own behind leaves that child holding the pipe.
    ///
    /// The wait before cancelling is a handshake rather than a duration: the pipe holds unread
    /// bytes until the read under test takes them, so an empty pipe is proof that the read is
    /// under way. A fixed sleep proves nothing, and a cancel that arrived before the read started
    /// would pass this test while testing the opposite of what it claims.
    @Test(.timeLimit(.minutes(1)))
    func cancellingAReadReturnsWithoutWaitingForTheWriterToClose() async throws {
        let pipe = Pipe()
        let reader = pipe.fileHandleForReading
        // Read once and kept, because asking a closed `FileHandle` for its descriptor raises
        // rather than answering, and this test has to survive the failure it is looking for.
        let descriptor = reader.fileDescriptor
        defer { try? pipe.fileHandleForWriting.close() }
        try pipe.fileHandleForWriting.write(contentsOf: Data(repeating: UInt8(ascii: "a"), count: 1_024))

        let read = Task { try await GitProcessIO.readData(from: reader, limit: nil) }
        try await Self.waitUntilRead(from: descriptor)
        read.cancel()

        let started = ContinuousClock.now
        let result = await read.result
        let elapsed = started.duration(to: .now)

        #expect(throws: CancellationError.self) { try result.get() }
        #expect(elapsed < .seconds(5), "A cancelled read took \(elapsed) to come back")
        // The reader must never close the caller's descriptor: a descriptor number freed while a
        // read is still using it can be handed to the next pipe the app opens, and the read would
        // then be reading someone else's output.
        #expect(fcntl(descriptor, F_GETFD) != -1, "A cancelled read closed the handle it was given")
    }

    /// Waits until the pipe holds nothing left to read, which only the read under test can cause.
    private static func waitUntilRead(from descriptor: Int32) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while ContinuousClock.now < deadline {
            var polled = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
            if poll(&polled, 1, 0) == 0 {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("The read never took what was written to the pipe")
    }

    /// Writes the whole payload to one pipe and nothing to the other, closing both only once the
    /// payload is written, then reads them the way `GitProcess` does.
    private func readBothPipes(limit: Int?) async throws -> (output: Data, errorOutput: Data) {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let outputWriter = outputPipe.fileHandleForWriting
        let errorWriter = errorPipe.fileHandleForWriting
        let payload = Self.payload

        // Detached, because writing past the buffer blocks until the readers below start.
        let writer = Task.detached {
            try? outputWriter.write(contentsOf: payload)
            try? outputWriter.close()
            try? errorWriter.close()
        }

        async let output = GitProcessIO.readData(from: outputPipe.fileHandleForReading, limit: limit)
        async let errorOutput = GitProcessIO.readData(
            from: errorPipe.fileHandleForReading,
            limit: 4_000
        )
        let read = try await (output: output, errorOutput: errorOutput)
        await writer.value

        try? outputPipe.fileHandleForReading.close()
        try? errorPipe.fileHandleForReading.close()
        return read
    }
}
