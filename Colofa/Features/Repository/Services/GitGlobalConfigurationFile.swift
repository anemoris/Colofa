////
//  GitGlobalConfigurationFile.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which file `git config --global` writes to.
///
/// A scope is not a file. Git *reads* every global file it finds — `$XDG_CONFIG_HOME/git/config`
/// as well as `~/.gitconfig` — but it *writes* to exactly one of them, and a value that lives in
/// the other cannot be removed at that scope at all: `git config --global --unset-all` answers
/// exit status 5 and leaves the value in force. Offering such a value as editable would promise a
/// removal Colofa cannot perform, so knowing the file is part of knowing what may be edited.
///
/// This mirrors Git's own rule rather than inventing one: `GIT_CONFIG_GLOBAL` decides outright
/// when it is set, and otherwise `~/.gitconfig` is the target unless it cannot be read while the
/// XDG file can. Colofa runs Git with its own environment, so the same variables decide both.
nonisolated enum GitGlobalConfigurationFile {

    /// - Parameter isReadable: How a candidate's readability is established, which is what Git
    ///   itself tests rather than mere existence.
    /// - Returns: The path a `--global` write lands in, or `nil` when there is no home directory
    ///   to resolve one against and Git would refuse the write outright.
    static func writeTarget(
        environment: [String: String],
        isReadable: (String) -> Bool = { FileManager.default.isReadableFile(atPath: $0) }
    ) -> String? {
        // An explicit override replaces both candidates rather than joining them, which is why
        // the XDG file is not consulted at all here.
        if let overridden = environment["GIT_CONFIG_GLOBAL"], !overridden.isEmpty {
            return overridden
        }
        guard let home = environment["HOME"], !home.isEmpty else {
            return nil
        }

        let userConfig = URL(filePath: home).appending(path: ".gitconfig").path
        guard !isReadable(userConfig),
              let xdgConfig = xdgConfig(environment: environment, home: home),
              isReadable(xdgConfig) else {
            // The ordinary case, including the one where neither file exists yet: a write creates
            // `~/.gitconfig`.
            return userConfig
        }
        return xdgConfig
    }

    private static func xdgConfig(environment: [String: String], home: String) -> String? {
        let base: String
        if let configHome = environment["XDG_CONFIG_HOME"], !configHome.isEmpty {
            base = configHome
        } else {
            base = URL(filePath: home).appending(path: ".config").path
        }
        return URL(filePath: base).appending(path: "git").appending(path: "config").path
    }
}
