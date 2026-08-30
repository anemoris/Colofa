////
//  GitPushTargetParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Reading where a Push goes out of Git's own report about a Branch's upstream.
struct GitPushTargetParserTests {

    private func record(
        _ refname: String,
        remote: String = "origin",
        remoteRef: String = "refs/heads/main",
        short: String = "origin/main",
        upstream: String = "refs/remotes/origin/main"
    ) -> String {
        [refname, remote, remoteRef, short, upstream].joined(separator: "\0")
    }

    @Test
    func everyPartOfTheUpstreamIsReadFromGitsOwnAnswer() throws {
        let target = try #require(
            try GitPushTargetParser.parse(
                Data(record("refs/heads/main").utf8),
                branch: "main"
            )
        )

        #expect(target.remote == "origin")
        #expect(target.remoteRef == "refs/heads/main")
        #expect(target.upstream == "origin/main")
        #expect(target.trackingRef == "refs/remotes/origin/main")
        #expect(target.expectedObjectID == nil, "The configuration read invented an object")
    }

    /// `for-each-ref` matches a literal pattern up to a slash as well as completely, so the Ref
    /// has to be checked rather than trusted — pushing `feature/work` because it sorted first
    /// would be pushing a Branch the user never named.
    @Test
    func abranchIsNeverConfusedWithTheOnesBelowIt() throws {
        let output = [
            record("refs/heads/feature/work", remoteRef: "refs/heads/work", short: "origin/work"),
            record("refs/heads/feature", remoteRef: "refs/heads/feature", short: "origin/feature"),
        ]
        .joined(separator: "\n")

        let target = try #require(
            try GitPushTargetParser.parse(Data(output.utf8), branch: "feature")
        )

        #expect(target.remoteRef == "refs/heads/feature")
        #expect(target.upstream == "origin/feature")
    }

    /// A Branch nobody has pushed yet reports every upstream field empty, which is the state
    /// Publish answers rather than Push.
    @Test
    func abranchWithNoUpstreamReportsNoTarget() throws {
        let output = ["refs/heads/main", "", "", "", ""].joined(separator: "\0")

        #expect(try GitPushTargetParser.parse(Data(output.utf8), branch: "main") == nil)
    }

    /// A Ref that is not there at all is the same answer: there is nowhere for a Push to go.
    @Test
    func arefTheReadNeverReportedIsNoTargetEither() throws {
        #expect(try GitPushTargetParser.parse(Data(), branch: "main") == nil)
        #expect(
            try GitPushTargetParser.parse(
                Data(record("refs/heads/other").utf8),
                branch: "main"
            ) == nil
        )
    }

    /// A record Colofa does not understand is refused rather than half-read: guessing which field
    /// was missing is guessing where a Push goes.
    @Test(arguments: ["refs/heads/main\0origin", "refs/heads/main\0origin\0a\0b\0c\0d"])
    func arecordWithTheWrongNumberOfFieldsIsRefused(_ output: String) {
        #expect(throws: GitOutputParsingError.self) {
            try GitPushTargetParser.parse(Data(output.utf8), branch: "main")
        }
    }
}
