////
//  ConflictVersionTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// The two complete versions a conflicted path can be restored to.
struct ConflictVersionTests {
    private let change = RepositoryChange(path: "conflict.txt", kind: .conflict)

    @Test(
        arguments: [
            (ConflictVersion.current, "--ours"),
            (ConflictVersion.incoming, "--theirs"),
        ]
    )
    func eachVersionRestoresItsOwnSideOfTheConflict(
        version: ConflictVersion,
        option: String
    ) {
        #expect(
            version.arguments(for: change)
                == ["--literal-pathspecs", "checkout", option, "--", "conflict.txt"]
        )
    }

    /// Restoring a version writes the working tree and nothing else, so nothing here stages the
    /// path: Mark as Resolved is the separate, explicit step that ends the Conflict.
    @Test(arguments: ConflictVersion.allCases)
    func noVersionChoiceStagesThePath(version: ConflictVersion) {
        let arguments = version.arguments(for: change)

        #expect(!arguments.contains("add"))
        #expect(!arguments.contains("--staged"))
    }

    /// The label is the whole distinction the user is given, and it is always a real Ref rather
    /// than a position in a Git command.
    @Test(arguments: ConflictVersion.allCases)
    func aVersionIsOfferedUnderTheRefItNames(version: ConflictVersion) {
        let title = englishText(version.title("release/2.0"))

        #expect(title.contains("release/2.0"))
        #expect(!title.localizedCaseInsensitiveContains("ours"))
        #expect(!title.localizedCaseInsensitiveContains("theirs"))
    }
}
