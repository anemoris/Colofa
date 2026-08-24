////
//  AskPassChannelSupport.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Foundation
import Testing
@testable import Colofa

/// The channel a command was pointed at, read out of the environment it reported.
nonisolated func reportedSocketPath(in environmentURL: URL) throws -> String {
    let reported = try String(contentsOf: environmentURL, encoding: .utf8)
    let prefix = "\(GitAskPassSocket.socketVariable)="
    return try #require(
        reported
            .split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    )
}

/// Connects to a bridge's socket the way an AskPass program does, without being one.
nonisolated func connectedSocket(to socketPath: String) throws -> Int32 {
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    try #require(descriptor >= 0)

    var address = try GitAskPassSocket.address(for: socketPath)
    let connected = GitAskPassSocket.withAddress(&address) { pointer, length in
        connect(descriptor, pointer, length)
    }
    guard connected == 0 else {
        close(descriptor)
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    return descriptor
}

/// Reads until Colofa closes its end, refusing to wait forever for an end that never closes.
///
/// - Returns: What arrived before the close, or `nil` when nothing closed in time — which is a
///   connection Colofa is still holding open.
nonisolated func readUntilClosed(_ descriptor: Int32, timeout: Duration = .seconds(5)) -> Data? {
    var window = timeval(tv_sec: Int(timeout.components.seconds), tv_usec: 0)
    setsockopt(
        descriptor,
        SOL_SOCKET,
        SO_RCVTIMEO,
        &window,
        socklen_t(MemoryLayout<timeval>.size)
    )

    var received = Data()
    var buffer = [UInt8](repeating: 0, count: 256)
    while true {
        let count = buffer.withUnsafeMutableBytes { destination in
            Darwin.read(descriptor, destination.baseAddress, destination.count)
        }
        if count == 0 {
            return received
        }
        if count < 0 {
            guard errno == EINTR else {
                return nil
            }
            continue
        }
        received.append(contentsOf: buffer[0..<count])
    }
}

/// Whether the process `pidURL` names has ended, waited for rather than assumed.
nonisolated func waitUntilProcessEnded(
    reportedAt pidURL: URL,
    timeout: Duration = .seconds(10)
) async throws -> Bool {
    let reported = try String(contentsOf: pidURL, encoding: .utf8)
    let pid = try #require(pid_t(reported.trimmingCharacters(in: .whitespacesAndNewlines)))
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if kill(pid, 0) != 0 {
            return true
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    return false
}

/// Writes `data` to a connection the way an AskPass program does, and half-closes so the reading
/// end knows the message ended.
///
/// - Returns: Whether all of it was written. A message the bridge refused part-way through is
///   refused by closing, so a short write is an outcome rather than a fault.
@discardableResult
nonisolated func writeAndFinish(_ data: Data, to descriptor: Int32) -> Bool {
    var remaining = data[...]
    while !remaining.isEmpty {
        let written = remaining.withUnsafeBytes { buffer in
            Darwin.write(descriptor, buffer.baseAddress, buffer.count)
        }
        if written < 0 {
            guard errno == EINTR else {
                return false
            }
            continue
        }
        remaining = remaining.dropFirst(written)
    }
    shutdown(descriptor, SHUT_WR)
    return true
}

/// A socket standing in for a bridge, so a test can answer Colofa's AskPass program with something
/// no bridge would ever send.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: it is accepted on
/// whatever thread a test is running on.
nonisolated final class StandInBridge: Sendable {

    /// What an AskPass program needs in its environment to ask this stand-in instead.
    let environment: [String: String]

    private let descriptor: Int32
    private let directoryURL: URL

    /// - Throws: `POSIXError` when the socket cannot be created, bound, or listened on.
    init(token: String) throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appending(path: "colofa-stand-in-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let socketPath = directoryURL.appending(path: "s").normalizedFilePath

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var address = try GitAskPassSocket.address(for: socketPath)
        let bound = GitAskPassSocket.withAddress(&address) { pointer, length in
            bind(descriptor, pointer, length)
        }
        guard bound == 0, listen(descriptor, 4) == 0 else {
            let code = errno
            close(descriptor)
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }

        self.descriptor = descriptor
        environment = [
            GitAskPassSocket.socketVariable: socketPath,
            GitAskPassSocket.tokenVariable: token,
        ]
    }

    deinit {
        close(descriptor)
        try? FileManager.default.removeItem(at: directoryURL)
    }

    /// Starts waiting for one connection, answers it with `reply`, and closes.
    ///
    /// Waits on a thread of its own because accepting blocks, and the program it is waiting for is
    /// run by the test that called this.
    func beginAnswering(with reply: Data) {
        let thread = Thread { [self] in
            let client = accept(descriptor, nil, nil)
            guard client >= 0 else {
                return
            }
            defer { close(client) }
            _ = readUntilClosed(client)
            writeAndFinish(reply, to: client)
        }
        thread.name = "com.anemoris.Colofa.stand-in-bridge"
        thread.start()
    }
}
