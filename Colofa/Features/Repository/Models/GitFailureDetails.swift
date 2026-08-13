////
//  GitFailureDetails.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct GitFailureDetails: Equatable, Sendable {
    let command: String
    let output: String
    let exitStatus: Int32?

    nonisolated init(command: String, output: String, exitStatus: Int32? = nil) {
        self.command = command
        self.output = output
        self.exitStatus = exitStatus
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.command == rhs.command
            && lhs.output == rhs.output
            && lhs.exitStatus == rhs.exitStatus
    }
}
