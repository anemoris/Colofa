////
//  GitGlobalConfigurationFileTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Which of Git's global files a `--global` write lands in.
///
/// The rule is Git's, not Colofa's, and getting it wrong is what makes the app offer a removal
/// Git answers with exit status 5 while the value stays in force.
struct GitGlobalConfigurationFileTests {
    private let home = "/Users/test"

    private func writeTarget(
        _ environment: [String: String],
        readable: Set<String> = []
    ) -> String? {
        GitGlobalConfigurationFile.writeTarget(
            environment: environment,
            isReadable: { readable.contains($0) }
        )
    }

    /// The ordinary machine: one global file, and it is the one written to.
    @Test
    func writesToTheHomeConfigurationWhenItIsThere() {
        let target = writeTarget(["HOME": home], readable: ["\(home)/.gitconfig"])

        #expect(target == "\(home)/.gitconfig")
    }

    /// Nothing to read yet is still an answer: a write creates `~/.gitconfig`.
    @Test
    func writesToTheHomeConfigurationWhenNeitherFileExists() {
        #expect(writeTarget(["HOME": home]) == "\(home)/.gitconfig")
    }

    /// The XDG file is only the target when Git has no `~/.gitconfig` to prefer over it.
    @Test
    func writesToTheXdgConfigurationOnlyWhenTheHomeOneCannotBeRead() {
        let xdg = "\(home)/.config/git/config"

        #expect(writeTarget(["HOME": home], readable: [xdg]) == xdg)
        #expect(
            writeTarget(["HOME": home], readable: [xdg, "\(home)/.gitconfig"])
                == "\(home)/.gitconfig"
        )
    }

    /// The case the bug lived in: both files exist, Git reads both, and a value in the XDG one
    /// cannot be unset with `--global` because the write goes to the other file entirely.
    @Test
    func honoursAnExplicitXdgLocation() {
        let environment = ["HOME": home, "XDG_CONFIG_HOME": "/Users/test/elsewhere"]
        let xdg = "/Users/test/elsewhere/git/config"

        #expect(writeTarget(environment, readable: [xdg]) == xdg)
        #expect(
            writeTarget(environment, readable: [xdg, "\(home)/.gitconfig"])
                == "\(home)/.gitconfig"
        )
    }

    /// An override replaces both candidates rather than joining them, so the XDG file is not
    /// consulted at all — which is Git's behaviour, and the reason it is not consulted here.
    @Test
    func anExplicitOverrideDecidesOnItsOwn() {
        let target = writeTarget(
            [
                "HOME": home,
                "XDG_CONFIG_HOME": "/Users/test/elsewhere",
                "GIT_CONFIG_GLOBAL": "/Users/test/pinned.gitconfig",
            ],
            readable: ["/Users/test/elsewhere/git/config", "\(home)/.gitconfig"]
        )

        #expect(target == "/Users/test/pinned.gitconfig")
    }

    /// Without a home directory Git has no global file to write, and claiming one would make
    /// every global value look editable again.
    @Test
    func reportsNoTargetWithoutAHomeDirectory() {
        #expect(writeTarget([:]) == nil)
        #expect(writeTarget(["HOME": ""]) == nil)
    }
}
