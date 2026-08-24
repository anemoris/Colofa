////
//  GitAskPassConnection.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Dispatch
import Foundation

/// One AskPass program's connection to Colofa, carrying one question and one answer.
///
/// Reading and writing go through a Dispatch I/O channel rather than the socket descriptor for
/// the same reason `GitPipeChannel` does: a blocking read sits inside a syscall that a cancelled
/// task cannot reach, and closing the descriptor underneath one frees a number the app may be
/// handed again. Closing the channel is a documented operation on the channel and touches no
/// descriptor anyone else can be given.
///
/// The channel owns the descriptor and closes it once every operation on it has ended, so a
/// connection nobody serves — one buffered behind a bridge that has already been torn down —
/// still releases what it holds when it is released.
///
/// Every operation ends when the task waiting on it is cancelled. A connection Colofa did not
/// open decides when it stops writing and when it starts reading, so without that a program that
/// simply connects and waits would hold the channel, its descriptor, and the task serving it for
/// as long as it liked — including past the teardown of the command they all belong to.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: this work must
/// stay off the main actor.
nonisolated final class GitAskPassConnection: Sendable {

    /// What process is on the other end, as the kernel reports it rather than as the connection
    /// claims. `nil` when the kernel would not say, which is a peer that ended between being
    /// accepted and being asked about.
    ///
    /// Read while the descriptor is still bare, because from here on it belongs to the channel.
    let peerProcessID: pid_t?

    private let channel: DispatchIO
    private let queue: DispatchQueue

    init(descriptor: Int32, queue: DispatchQueue) {
        self.queue = queue
        peerProcessID = Self.peerProcessID(of: descriptor)
        channel = DispatchIO(type: .stream, fileDescriptor: descriptor, queue: queue) { _ in
            close(descriptor)
        }
    }

    deinit {
        channel.close(flags: .stop)
    }

    private static func peerProcessID(of descriptor: Int32) -> pid_t? {
        var processID = pid_t()
        var length = socklen_t(MemoryLayout<pid_t>.size)
        guard getsockopt(descriptor, SOL_LOCAL, LOCAL_PEERPID, &processID, &length) == 0,
              length == socklen_t(MemoryLayout<pid_t>.size),
              processID > 0 else {
            return nil
        }
        return processID
    }

    /// The question the AskPass program asked, read until it stops writing.
    ///
    /// - Parameter limit: What a question may occupy. A connection Colofa did not open decides
    ///   nothing about how much it may send, so one byte past the limit is read deliberately:
    ///   stopping at the limit itself would leave a question that ran over indistinguishable from
    ///   one that ended there, and the difference is whether what follows is the rest of the
    ///   question or nothing at all.
    /// - Returns: What was read, or `nil` when the connection failed before finishing or sent more
    ///   than `limit`. A question that ran over is refused whole rather than answered on the part
    ///   of it that arrived, because a prompt read to its limit is a prompt whose meaning is
    ///   decided by text nobody saw.
    func question(limit: Int) async -> Data? {
        let accumulated = Accumulated()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                channel.read(offset: 0, length: limit + 1, queue: queue) { done, data, error in
                    if let data, !data.isEmpty {
                        accumulated.append(Data(data))
                    }
                    guard done else {
                        return
                    }
                    let read = accumulated.data
                    continuation.resume(
                        returning: error == 0 && read.count <= limit ? read : nil
                    )
                }
            }
        } onCancel: {
            // Ends the read rather than waiting for a peer that may never stop writing. A read
            // on a closed channel is delivered as a failed one, so the question resolves to the
            // nothing it turned out to be.
            channel.close(flags: .stop)
        }
    }

    /// Hands `data` back and closes the connection, which is what tells the AskPass program the
    /// answer ended.
    func answer(_ data: Data) async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                channel.write(
                    offset: 0,
                    data: data.withUnsafeBytes { DispatchData(bytes: $0) },
                    queue: queue
                ) { done, _, _ in
                    guard done else {
                        return
                    }
                    continuation.resume()
                }
            }
        } onCancel: {
            // The command this answer belonged to is over, so the program that asked is too.
            // Discarding the write is what ends the wait; delivering half an answer to a process
            // that is no longer there would be the only alternative.
            channel.close(flags: .stop)
        }
        channel.close()
    }
}

/// What a read has collected so far. Declared alongside because Dispatch I/O delivers a read in
/// pieces through an escaping handler, which cannot accumulate into a local variable.
///
/// Safe without a lock: every delivery for one read runs on that channel's own serial queue.
private nonisolated final class Accumulated: @unchecked Sendable {
    private(set) var data = Data()

    func append(_ chunk: Data) {
        data.append(chunk)
    }
}
