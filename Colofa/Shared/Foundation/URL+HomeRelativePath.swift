////
//  URL+HomeRelativePath.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

extension URL {

    /// The file path as it is shown to the user: home-relative when it lies inside the home
    /// directory, and the absolute path otherwise.
    ///
    /// Two reasons a Repository path is displayed this way. It is shorter, which matters in the
    /// status bar and the inspector where a deep path otherwise wraps onto three lines. And it
    /// keeps the account name out of a screenshot, a screen share, or a pasted issue report —
    /// the same reason the project keeps personal paths out of version-controlled content.
    ///
    /// `home` is a parameter rather than read inside the body so a test can pin it. A test that
    /// resolved the real home would assert against the machine it runs on, and under the
    /// sandboxed UI-test runner it would resolve to that runner's container rather than to the
    /// home the app itself sees.
    ///
    /// Declared `nonisolated` to match `normalizedFilePath`: both are read from an actor while
    /// the project defaults to Main Actor isolation.
    nonisolated func homeRelativeFilePath(home: String = NSHomeDirectory()) -> String {
        let path = normalizedFilePath
        let root = home.count > 1 && home.hasSuffix("/") ? String(home.dropLast()) : home

        // An empty or root home would abbreviate every path on the volume, which says nothing.
        guard !root.isEmpty, root != "/" else {
            return path
        }
        if path == root {
            return "~"
        }
        // Match whole path components: a sibling directory such as `/Users/mia-archive` shares a
        // prefix with `/Users/mia` and must keep its absolute path rather than become `~-archive`.
        guard path.hasPrefix(root + "/") else {
            return path
        }
        return "~" + path.dropFirst(root.count)
    }
}
