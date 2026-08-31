////
//  GitConfigurationOrigin.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

struct GitConfigurationOrigin: Equatable, Hashable, Sendable {
    let rawValue: String

    nonisolated var location: String {
        guard rawValue.hasPrefix("file:") else {
            return rawValue
        }
        return String(rawValue.dropFirst("file:".count))
    }

    /// Whether this entry was read from the file at `path`.
    ///
    /// Compared as file system locations rather than as text. Git reports the path it was handed,
    /// which is built from the same variables Colofa reads but need not be spelled the same way;
    /// both sides are put through one normalization so a redundant component or a symlinked home
    /// cannot make one file look like two.
    ///
    /// An origin that is not a file — the command line, standard input, a blob — is never one.
    nonisolated func isFile(at path: String) -> Bool {
        guard rawValue.hasPrefix("file:") else {
            return false
        }
        return Self.resolved(location) == Self.resolved(path)
    }

    private nonisolated static func resolved(_ path: String) -> String {
        URL(filePath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }
}
