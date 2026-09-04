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

    /// The origin as it is shown to the user: a file is home-relative, anything else is left
    /// exactly as Git worded it.
    ///
    /// Only a `file:` origin is a path. Git also reports the command line, standard input, a
    /// blob, and remote configuration, and none of those is a location on this disk — putting
    /// them through path abbreviation would be claiming they are.
    ///
    /// `home` is a parameter for the same reason it is on `homeRelativeFilePath`: a test must be
    /// able to pin it instead of asserting against the account it runs under.
    nonisolated func displayLocation(home: String = NSHomeDirectory()) -> String {
        guard rawValue.hasPrefix("file:") else {
            return rawValue
        }
        return URL(filePath: location).homeRelativeFilePath(home: home)
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
