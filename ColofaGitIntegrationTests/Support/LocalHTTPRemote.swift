////
//  LocalHTTPRemote.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Foundation
import os

/// A real HTTP remote on the loopback interface that demands Basic authentication.
///
/// Git asks for a credential only after a server has refused one, so reaching Colofa's channel the
/// way Git actually reaches it needs a server that refuses. This answers the request `ls-remote`
/// makes for a remote's refs: without an `Authorization` header it replies `401` naming Basic
/// authentication, and the retry that follows is recorded and then refused, so the command ends
/// without a Git server having to exist behind it.
///
/// Bound to `127.0.0.1` on a port the kernel picks, so it is reachable from nothing outside this
/// machine and collides with nothing else on it.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: it answers on a
/// thread of its own.
nonisolated final class LocalHTTPRemote: Sendable {

    /// The port the kernel assigned, which is the only part of the address a test has to be told.
    let port: UInt16

    private let descriptor: Int32
    private let authorizations = OSAllocatedUnfairLock(initialState: [String]())

    /// - Throws: `POSIXError` when the socket cannot be created, bound, listened on, or named.
    init() throws {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var reuse: Int32 = 1
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        // Port zero asks the kernel for one nobody else is holding, so two runs never collide.
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &length)
            }
        }

        guard bound == 0, listen(descriptor, 8) == 0, named == 0 else {
            let code = errno
            close(descriptor)
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        self.descriptor = descriptor
        port = UInt16(bigEndian: assigned.sin_port)

        let thread = Thread { [self] in
            serve()
        }
        thread.name = "com.anemoris.Colofa.local-http-remote"
        thread.start()
    }

    deinit {
        stop()
    }

    /// Where a repository on this remote lives, written the way a user would type it.
    func repositoryURL(named name: String) -> String {
        "http://127.0.0.1:\(port)/\(name)"
    }

    /// Every `Authorization` header this remote was sent, in the order they arrived.
    var receivedAuthorizations: [String] {
        authorizations.withLock { $0 }
    }

    /// Stops answering. Callable more than once.
    func stop() {
        // Shut down before closing: a thread already blocked in `accept` is woken by the shutdown
        // rather than left waiting on a descriptor number that has gone.
        shutdown(descriptor, SHUT_RDWR)
        close(descriptor)
    }

    private func serve() {
        while true {
            let client = accept(descriptor, nil, nil)
            // A closed listener is how this ends, so a failed accept is the stop rather than an
            // error to report.
            guard client >= 0 else {
                return
            }
            respond(on: client)
            close(client)
        }
    }

    private func respond(on client: Int32) {
        guard let request = Self.read(from: client) else {
            return
        }
        guard let authorization = Self.authorization(in: request) else {
            Self.write(
                Self.response(
                    status: "401 Unauthorized",
                    headers: [#"WWW-Authenticate: Basic realm="Colofa""#],
                    body: "authentication required\n"
                ),
                to: client
            )
            return
        }
        authorizations.withLock { $0.append(authorization) }
        // Refused rather than accepted: what this proves is which credential arrived, and
        // answering would mean speaking the Git transfer protocol for no further benefit.
        Self.write(
            Self.response(status: "403 Forbidden", headers: [], body: "refused\n"),
            to: client
        )
    }

    /// The request head, read until the blank line that ends it.
    ///
    /// - Returns: What arrived, or `nil` when the peer went away or sent more head than any
    ///   request Git makes.
    private static func read(from client: Int32) -> String? {
        var window = timeval(tv_sec: 10, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &window, socklen_t(MemoryLayout<timeval>.size))

        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while received.count <= maximumRequestSize {
            let count = buffer.withUnsafeMutableBytes { destination in
                Darwin.read(client, destination.baseAddress, destination.count)
            }
            guard count > 0 else {
                return nil
            }
            received.append(contentsOf: buffer[0..<count])
            if let head = String(data: received, encoding: .utf8), head.contains("\r\n\r\n") {
                return head
            }
        }
        return nil
    }

    private static func authorization(in request: String) -> String? {
        let prefix = "authorization:"
        return request
            .split(whereSeparator: \.isNewline)
            .first { $0.lowercased().hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces) }
    }

    private static func response(status: String, headers: [String], body: String) -> Data {
        let head = (
            ["HTTP/1.1 \(status)"]
                + headers
                + [
                    "Content-Type: text/plain",
                    "Content-Length: \(body.utf8.count)",
                    "Connection: close",
                ]
        ).joined(separator: "\r\n")
        return Data("\(head)\r\n\r\n\(body)".utf8)
    }

    private static func write(_ data: Data, to client: Int32) {
        var remaining = data[...]
        while !remaining.isEmpty {
            let written = remaining.withUnsafeBytes { buffer in
                Darwin.write(client, buffer.baseAddress, buffer.count)
            }
            guard written > 0 else {
                return
            }
            remaining = remaining.dropFirst(written)
        }
    }

    /// More than the head of any request Git sends for a remote's refs, and small enough that a
    /// peer which never stops writing is dropped rather than accumulated.
    private static let maximumRequestSize = 16 * 1_024
}
