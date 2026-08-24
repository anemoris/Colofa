////
//  GitSecretRedaction.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import os

/// What one running command has learned that must never be repeated back.
///
/// Standard input is known before a command starts, so `GitProcess` can redact it from the
/// beginning. An authentication answer is not: it exists only because the command asked for it
/// halfway through. This collects those values while the command runs, so the failure details
/// built afterwards can remove them from Git's own words.
///
/// Nothing here is written anywhere. It lives as long as the command does and is released with
/// it, which is the whole of Colofa's relationship with a secret.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: the AskPass
/// bridge adds to this from a socket, and `GitProcess` reads it while building failure details
/// off the main actor.
nonisolated final class GitSecretRedaction: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [String]())

    init() {}

    /// Records every form of `value`, so a message quoting part of it cannot leave the rest
    /// behind.
    ///
    /// A form that is only whitespace is dropped rather than recorded. Redaction replaces whole
    /// words, and a space is a word boundary — recording one would blank out the spacing of every
    /// message Git wrote rather than a secret inside it.
    func record(_ value: String) {
        let values = GitOutputRedaction.sensitiveValues(from: value).filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !values.isEmpty else {
            return
        }
        storage.withLock { stored in
            for value in values where !stored.contains(value) {
                stored.append(value)
            }
        }
    }

    /// Everything recorded so far, longest first, which is the order redaction has to apply them
    /// in.
    var values: [String] {
        storage.withLock { $0 }.sorted { $0.count > $1.count }
    }
}
