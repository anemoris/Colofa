////
//  GitPipeChannel.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Dispatch
import Foundation

/// One of a Git process's pipes, delivered as chunks and stoppable from another task.
///
/// Reading goes through a Dispatch I/O channel rather than straight off the `FileHandle`, because
/// abandoning a read is the hard part. A blocking read sits inside a syscall where a cancelled task
/// cannot reach it, and the only way to reach it from outside is to close the descriptor from
/// another thread — which frees the descriptor number while a read is still using it, so whatever
/// the app opens next can be handed that number and be read from by mistake. Closing a channel is a
/// documented operation on the channel: it ends that channel's outstanding reads and touches no
/// descriptor anyone else can be given.
///
/// The channel reads a duplicate of the descriptor and closes only that duplicate, so the handle
/// the caller owns stays open and stays theirs to close.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: this work must stay
/// off the main actor.
nonisolated struct GitPipeChannel: Sendable {
    /// What the pipe delivered, in the order it arrived, ending when the last writer closes it.
    ///
    /// One channel reads one pipe once, so this is iterated once and by one consumer.
    let chunks: AsyncThrowingStream<Data, any Error>

    private let channel: DispatchIO

    /// - Throws: `POSIXError` when the handle's descriptor cannot be duplicated.
    init(reading handle: FileHandle) throws {
        let descriptor = dup(handle.fileDescriptor)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        let queue = DispatchQueue(label: "com.anemoris.Colofa.git-pipe-read", qos: .userInitiated)
        // The duplicate belongs to the channel from here on, and the cleanup handler is where a
        // channel hands a descriptor back: it runs once every operation on the channel has ended.
        let channel = DispatchIO(type: .stream, fileDescriptor: descriptor, queue: queue) { _ in
            close(descriptor)
        }
        // Bounds one delivery, never the read: the pipe has to keep being emptied either way, or
        // Git blocks writing into a full one and never exits.
        channel.setLimit(highWater: Self.chunkSize)

        self.channel = channel
        chunks = AsyncThrowingStream { continuation in
            // Set before the read starts, so a pipe that ends immediately still releases the
            // channel. Stopping an already finished channel does nothing.
            continuation.onTermination = { _ in channel.close(flags: .stop) }
            channel.read(offset: 0, length: .max, queue: queue) { done, data, error in
                if let data, !data.isEmpty {
                    continuation.yield(Data(data))
                }
                guard done else { return }
                guard error == 0 else {
                    continuation.finish(throwing: POSIXError(POSIXErrorCode(rawValue: error) ?? .EIO))
                    return
                }
                continuation.finish()
            }
        }
    }

    /// Ends the read wherever it is, which the stopped read reports as `ECANCELED`.
    ///
    /// Callable from any task: this closes a channel, not a descriptor, so nothing here races a
    /// read for a descriptor number.
    func stop() {
        channel.close(flags: .stop)
    }

    /// One 64 KiB delivery, which is what a pipe holds on macOS.
    private static let chunkSize = 64 * 1_024
}
