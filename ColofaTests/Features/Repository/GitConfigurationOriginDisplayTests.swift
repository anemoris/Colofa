////
//  GitConfigurationOriginDisplayTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Covers how a configuration entry's origin is written for the inspector. `home` is pinned in
/// every case so the suite asserts the rule rather than the account it runs under.
struct GitConfigurationOriginDisplayTests {
    private let home = "/Users/mia"

    @Test
    func globalConfigurationFileBecomesHomeRelative() {
        let origin = GitConfigurationOrigin(rawValue: "file:/Users/mia/.gitconfig")
        #expect(origin.displayLocation(home: home) == "~/.gitconfig")
    }

    @Test
    func repositoryConfigurationFileBecomesHomeRelative() {
        let origin = GitConfigurationOrigin(
            rawValue: "file:/Users/mia/Developer/Colofa/.git/config"
        )
        #expect(origin.displayLocation(home: home) == "~/Developer/Colofa/.git/config")
    }

    /// System configuration lives outside any home and keeps its absolute path.
    @Test
    func systemConfigurationFileKeepsItsAbsolutePath() {
        let origin = GitConfigurationOrigin(rawValue: "file:/etc/gitconfig")
        #expect(origin.displayLocation(home: home) == "/etc/gitconfig")
    }

    /// The origins that are not files at all. Abbreviating these would present Git's own wording
    /// as though it were a path on this disk.
    @Test(arguments: ["command line:", "standard input:", "blob:HEAD:.gitmodules"])
    func nonFileOriginIsLeftExactlyAsGitWordedIt(rawValue: String) {
        let origin = GitConfigurationOrigin(rawValue: rawValue)
        #expect(origin.displayLocation(home: home) == rawValue)
    }

    /// The abbreviation must not change which file an entry is matched to; `isFile(at:)` is what
    /// decides scope, and it still compares the real location.
    @Test
    func abbreviationDoesNotAffectFileMatching() {
        let origin = GitConfigurationOrigin(rawValue: "file:/Users/mia/.gitconfig")
        #expect(origin.displayLocation(home: home) == "~/.gitconfig")
        #expect(origin.isFile(at: "/Users/mia/.gitconfig"))
        #expect(!origin.isFile(at: "~/.gitconfig"))
    }
}
