////
//  GitSkipFetchAllParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Reading `remote.<name>.skipFetchAll` out of Git's own NUL-delimited configuration output.
struct GitSkipFetchAllParserTests {
    private func output(_ records: [String]) -> Data {
        Data(records.map { "\($0)\0" }.joined().utf8)
    }

    @Test
    func readsTheRemotesGitReportsAsSkipped() throws {
        let skipped = try GitSkipFetchAllParser.parse(
            output(["remote.mirror.skipfetchall\ntrue", "remote.backup.skipfetchall\ntrue"])
        )

        #expect(skipped == ["mirror", "backup"])
    }

    /// Git canonicalizes the value before Colofa sees it, so only `true` means skipped.
    @Test
    func leavesOutARemoteConfiguredNotToBeSkipped() throws {
        let skipped = try GitSkipFetchAllParser.parse(
            output(["remote.origin.skipfetchall\nfalse", "remote.mirror.skipfetchall\ntrue"])
        )

        #expect(skipped == ["mirror"])
    }

    /// `--get-regexp` prints one record per scope Git read the key in, in the order it read
    /// them, and Git obeys the last one. A Repository that turns a globally skipped remote back
    /// on is the case that matters: Git fetches it, so Colofa must too.
    @Test
    func obeysTheLastValueGitPrintedForARemote() throws {
        let skipped = try GitSkipFetchAllParser.parse(
            output(["remote.origin.skipfetchall\ntrue", "remote.origin.skipfetchall\nfalse"])
        )

        #expect(skipped.isEmpty)
    }

    /// And the other way round, so the rule is the ordering rather than a preference for one
    /// value over the other.
    @Test
    func obeysARepositoryThatSkipsARemoteAllowedElsewhere() throws {
        let skipped = try GitSkipFetchAllParser.parse(
            output(["remote.origin.skipfetchall\nfalse", "remote.origin.skipfetchall\ntrue"])
        )

        #expect(skipped == ["origin"])
    }

    /// One remote's later value says nothing about another's.
    @Test
    func overridesOnlyTheRemoteTheLaterValueNames() throws {
        let skipped = try GitSkipFetchAllParser.parse(
            output([
                "remote.origin.skipfetchall\ntrue",
                "remote.mirror.skipfetchall\ntrue",
                "remote.origin.skipfetchall\nfalse",
            ])
        )

        #expect(skipped == ["mirror"])
    }

    @Test
    func readsNothingFromAnEmptyAnswer() throws {
        #expect(try GitSkipFetchAllParser.parse(Data()).isEmpty)
    }

    /// A remote name may contain dots, and only the section and variable around it are fixed.
    @Test
    func readsARemoteNameThatContainsDots() throws {
        let skipped = try GitSkipFetchAllParser.parse(
            output(["remote.my.mirror.skipfetchall\ntrue"])
        )

        #expect(skipped == ["my.mirror"])
    }

    @Test(
        arguments: [
            "remote.mirror.skipfetchall",
            "branch.main.skipfetchall\ntrue",
            "remote.mirror.prune\ntrue",
        ]
    )
    func refusesOutputItDoesNotUnderstand(_ record: String) {
        #expect(throws: GitOutputParsingError.self) {
            try GitSkipFetchAllParser.parse(output([record]))
        }
    }
}
