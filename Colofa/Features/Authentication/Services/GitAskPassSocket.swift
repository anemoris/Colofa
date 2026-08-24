////
//  GitAskPassSocket.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Foundation

/// Addressing one AskPass channel: where it is, how a program proves it belongs to it, and the
/// shape the socket calls want that address in.
///
/// Everything here is shared by the two ends. They are separate programs — Colofa and the AskPass
/// tool Git runs — and anything described twice is something they could come to disagree about.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation, and the AskPass
/// program has no main actor at all.
nonisolated enum GitAskPassSocket {

    /// Where the AskPass program finds the bridge that started it.
    static let socketVariable = "COLOFA_ASKPASS_SOCKET"

    /// What the AskPass program must present to be answered. It addresses one command's bridge
    /// and no other, which is what a stale or unrelated program fails to produce.
    static let tokenVariable = "COLOFA_ASKPASS_TOKEN"

    /// - Throws: `POSIXError.ENAMETOOLONG` when `path` does not fit a local socket address.
    static func address(for path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard bytes.count < capacity else {
            throw POSIXError(.ENAMETOOLONG)
        }

        withUnsafeMutablePointer(to: &address.sun_path) { path in
            path.withMemoryRebound(to: CChar.self, capacity: capacity) { destination in
                for (offset, byte) in bytes.enumerated() {
                    destination[offset] = CChar(bitPattern: byte)
                }
                destination[bytes.count] = 0
            }
        }
        return address
    }

    /// Runs `body` with `address` in the shape the socket calls take it in.
    static func withAddress<Result>(
        _ address: inout sockaddr_un,
        _ body: (UnsafePointer<sockaddr>, socklen_t) -> Result
    ) -> Result {
        withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }
}
