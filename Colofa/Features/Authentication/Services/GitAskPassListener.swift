////
//  GitAskPassListener.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Dispatch
import Foundation

/// The socket one Git operation's AskPass programs connect back to, delivered as connections.
///
/// A local socket rather than a pipe pair, because each question is its own connection: two
/// programs asking at once cannot be read as one conversation, and a program that arrives after
/// the operation ended finds nothing to connect to at all.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: accepting
/// connections must stay off the main actor.
nonisolated final class GitAskPassListener: Sendable {

    /// Every AskPass program that connected, in the order they arrived, ending when the listener
    /// stops.
    ///
    /// Buffered no deeper than the socket's own backlog. One operation asks one question at a
    /// time, so anything beyond that is a queue of descriptors held open for programs Colofa is
    /// not serving; the oldest is dropped rather than kept.
    ///
    /// A connection nobody takes is still closed: a `GitAskPassConnection` owns its descriptor
    /// and releases it, so one buffered behind a listener that has already stopped — or dropped
    /// to keep the buffer bounded — is closed when it is dropped.
    let connections: AsyncStream<GitAskPassConnection>

    private let source: DispatchSourceRead

    /// - Throws: `POSIXError` when the socket cannot be created, bound, or listened on.
    init(socketPath: String) throws {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var address = try GitAskPassSocket.address(for: socketPath)
        let bound = GitAskPassSocket.withAddress(&address) { pointer, length in
            bind(descriptor, pointer, length)
        }
        guard bound == 0, listen(descriptor, Self.backlog) == 0 else {
            let code = errno
            close(descriptor)
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }

        let queue = DispatchQueue(label: "com.anemoris.Colofa.git-askpass", qos: .userInitiated)
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        let (connections, continuation) = AsyncStream.makeStream(
            of: GitAskPassConnection.self,
            bufferingPolicy: .bufferingNewest(Int(Self.backlog))
        )
        source.setCancelHandler {
            close(descriptor)
            continuation.finish()
        }
        source.setEventHandler {
            let client = accept(descriptor, nil, nil)
            guard client >= 0 else {
                return
            }
            continuation.yield(GitAskPassConnection(descriptor: client, queue: queue))
        }
        source.resume()

        self.source = source
        self.connections = connections
    }

    deinit {
        source.cancel()
    }

    /// Stops accepting, which ends `connections` and leaves nothing for a later program to reach.
    ///
    /// Callable more than once: cancelling an already cancelled source does nothing.
    func stop() {
        source.cancel()
    }

    /// How many AskPass programs may be waiting to be accepted. One operation asks one question
    /// at a time, so this only has to absorb a program that arrives while the previous one is
    /// still being served.
    private static let backlog: Int32 = 4
}
