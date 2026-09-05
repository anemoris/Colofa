////
//  GitSearchPath.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The `PATH` Colofa hands to Git, which is deliberately not the one Colofa was launched with.
///
/// Git resolves programs of its own through `PATH` — `git-lfs` and every other subcommand that
/// ships as a separate binary, credential helpers, remote helpers for transports Git does not
/// carry, custom merge and diff drivers, hooks. Those lookups happen inside a process Colofa has
/// already handed off to, so knowing where Git itself is says nothing about them.
///
/// An app launched from Finder, Dock, or Xcode inherits launchd's `PATH` of
/// `/usr/bin:/bin:/usr/sbin:/sbin`. The shell profile that normally adds a package manager's
/// prefix never runs for a GUI app, so Git would search four directories no package manager
/// installs into, and every one of those helpers would be missing with a confusing message of its
/// own.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while a Git command
/// reads this off it.
nonisolated enum GitSearchPath {

    /// Where the package managers on macOS put the programs Git runs: Homebrew on Apple silicon,
    /// the traditional local prefix Homebrew on Intel also uses, and MacPorts.
    ///
    /// A fixed list only covers installs that landed where it expects. A version manager's shims —
    /// asdf, mise, Nix — still resolve only when Colofa is launched from a shell that already put
    /// them on `PATH`. In exchange it costs no process launch, cannot hang or prompt, and cannot
    /// go stale against a profile the user edits.
    static let wellKnownDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/opt/local/bin",
    ]

    /// Where macOS itself keeps the programs Git runs: Apple's Git shim, and the `ssh` every SSH
    /// remote goes through.
    ///
    /// Named separately from the package-manager locations because it is not one of them. It is
    /// here for the `PATH` that does not mention `/usr/bin` at all — rare, but a `PATH` Colofa
    /// found Git on and Git cannot find `ssh` on is the exact failure this type exists to prevent.
    static let standardDirectories = ["/usr/bin"]

    /// Every directory Git should search, in the order it should search them.
    ///
    /// The added locations are appended rather than prepended, so a `PATH` the user's own
    /// environment established still decides which of two installed copies wins. This only adds
    /// destinations that `PATH` never mentioned.
    static func directories(in environment: [String: String]) -> [String] {
        // An entry that is not an absolute path means the current directory to Git as it does to
        // a shell — the empty entry a `PATH` writes as `::`, `.` spelled outright, and anything
        // relative to it. Colofa runs Git in the Repository, so keeping one would let a program
        // committed to the Repository be run in place of the helper Git asked for. Nothing usable
        // is lost with it: such an entry was written against the directory a shell runs in, which
        // is never the one Colofa runs Git in.
        let inherited = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { $0.hasPrefix("/") }

        let added = wellKnownDirectories + standardDirectories

        return (inherited + added).reduce(into: []) { directories, directory in
            if !directories.contains(directory) {
                directories.append(directory)
            }
        }
    }

    /// `environment` with the `PATH` Git is actually able to find its helper programs on.
    static func resolving(_ environment: [String: String]) -> [String: String] {
        environment.merging(
            ["PATH": directories(in: environment).joined(separator: ":")]
        ) { _, resolved in
            resolved
        }
    }
}
