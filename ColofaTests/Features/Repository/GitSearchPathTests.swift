////
//  GitSearchPathTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The `PATH` Git is given to find its own helper programs on.
///
/// An app launched from Finder inherits launchd's four directories, and no package manager
/// installs into any of them — which is why a `git-lfs` sitting in `/opt/homebrew/bin` is
/// invisible to Git and takes a fetch down with a message about the remote hanging up.
struct GitSearchPathTests {

    /// The launchd environment a GUI app actually starts in.
    private let launchdPath = "/usr/bin:/bin:/usr/sbin:/sbin"

    @Test
    func addsEveryWellKnownLocationToTheLaunchdSearchPath() {
        let directories = GitSearchPath.directories(in: ["PATH": launchdPath])

        #expect(
            directories == [
                "/usr/bin", "/bin", "/usr/sbin", "/sbin",
                "/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin",
            ]
        )
    }

    /// What the user's own environment says still decides which of two installed copies wins.
    @Test
    func keepsInheritedDirectoriesAheadOfTheWellKnownOnes() {
        let directories = GitSearchPath.directories(in: ["PATH": "/opt/mise/shims:/usr/bin"])

        #expect(directories.first == "/opt/mise/shims")
        #expect(directories.prefix(2).contains("/opt/homebrew/bin") == false)
    }

    /// A directory the shell already put on `PATH` keeps the position the shell gave it, rather
    /// than appearing twice.
    @Test
    func namesEachDirectoryOnce() {
        let directories = GitSearchPath.directories(
            in: ["PATH": "/opt/homebrew/bin:/usr/bin:/opt/homebrew/bin"]
        )

        #expect(directories == ["/opt/homebrew/bin", "/usr/bin", "/usr/local/bin", "/opt/local/bin"])
    }

    @Test
    func stillNamesTheAddedLocationsWithoutAnInheritedSearchPath() {
        let added = GitSearchPath.wellKnownDirectories + GitSearchPath.standardDirectories

        #expect(GitSearchPath.directories(in: [:]) == added)
        #expect(GitSearchPath.directories(in: ["PATH": ""]) == added)
    }

    /// A `PATH` that never names `/usr/bin` is where the two lists could have disagreed: Colofa
    /// would find Apple's Git shim there and hand Git a `PATH` with no `/usr/bin` on it, so the
    /// `ssh` every SSH remote goes through would be missing.
    @Test
    func namesTheStandardLocationTheInheritedSearchPathLeftOut() {
        let directories = GitSearchPath.directories(in: ["PATH": "/opt/homebrew/bin"])

        #expect(directories.contains("/usr/bin"))
        // Behind everything installed, so it never takes precedence it did not already have.
        #expect(directories.last == "/usr/bin")
    }

    /// An entry that is not an absolute path means the current directory, which for Colofa is the
    /// Repository. A program committed to a Repository must not be a candidate for a helper Git
    /// asked for by name, however the entry that would reach it happens to be spelled.
    @Test
    func dropsEveryEntryThatWouldMeanTheRepositoryItself() {
        let directories = GitSearchPath.directories(in: ["PATH": "/usr/bin:.:./tools::tools:/bin"])

        #expect(directories.contains("") == false)
        #expect(directories.contains(".") == false)
        #expect(directories.contains("./tools") == false)
        #expect(directories.contains("tools") == false)
        #expect(directories.prefix(2) == ["/usr/bin", "/bin"])
    }

    @Test
    func resolvingReplacesOnlyTheSearchPath() {
        let resolved = GitSearchPath.resolving(["PATH": launchdPath, "HOME": "/Users/test"])

        #expect(resolved["HOME"] == "/Users/test")
        #expect(
            resolved["PATH"] == GitSearchPath.directories(in: ["PATH": launchdPath])
                .joined(separator: ":")
        )
    }
}
