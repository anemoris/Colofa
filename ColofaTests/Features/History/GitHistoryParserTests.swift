////
//  GitHistoryParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct GitHistoryParserTests {
    @Test
    func readsEveryFieldOfOneCommit() throws {
        let commits = try GitHistoryParser.parse(
            Self.output([
                Self.record(
                    objectID: "1111111111111111111111111111111111111111",
                    abbreviated: "1111111",
                    parents: "2222222222222222222222222222222222222222",
                    authorName: "作者",
                    authorEmail: "author@example.invalid",
                    authoredAt: "1700000000",
                    committerName: "Committer",
                    committerEmail: "committer@example.invalid",
                    committedAt: "1700000060",
                    decoration: "",
                    summary: "Add a file"
                ),
            ])
        )

        let commit = try #require(commits.first)
        #expect(commits.count == 1)
        #expect(commit.objectID == "1111111111111111111111111111111111111111")
        #expect(commit.abbreviatedObjectID == "1111111")
        #expect(commit.parentObjectIDs == ["2222222222222222222222222222222222222222"])
        #expect(commit.authorName == "作者")
        #expect(commit.authorEmail == "author@example.invalid")
        #expect(commit.authoredDate == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(commit.committerName == "Committer")
        #expect(commit.committerEmail == "committer@example.invalid")
        #expect(commit.committedDate == Date(timeIntervalSince1970: 1_700_000_060))
        #expect(commit.summary == "Add a file")
        #expect(!commit.isMerge)
        #expect(!commit.isShallowBoundary)
    }

    @Test
    func keepsEveryCommitInTheOrderGitWalkedThem() throws {
        let commits = try GitHistoryParser.parse(
            Self.output([
                Self.record(objectID: "aaaa", summary: "Newest"),
                Self.record(objectID: "bbbb", summary: "Middle"),
                Self.record(objectID: "cccc", summary: "Oldest"),
            ])
        )

        #expect(commits.map(\.objectID) == ["aaaa", "bbbb", "cccc"])
    }

    @Test
    func readsAMergeAsTheCommitWithSeveralParents() throws {
        let commits = try GitHistoryParser.parse(
            Self.output([Self.record(objectID: "aaaa", parents: "bbbb cccc")])
        )

        let commit = try #require(commits.first)
        #expect(commit.parentObjectIDs == ["bbbb", "cccc"])
        #expect(commit.isMerge)
        // A merge is compared against the parent History walked through.
        #expect(commit.comparisonParentObjectID == "bbbb")
    }

    /// A root Commit and a shallow boundary both report no parent, and they are not the same
    /// fact: one is where the Repository starts, the other is where the clone stops.
    @Test
    func tellsARootCommitApartFromAShallowBoundary() throws {
        let root = try #require(
            try GitHistoryParser.parse(
                Self.output([Self.record(objectID: "aaaa", parents: "")])
            ).first
        )
        let boundary = try #require(
            try GitHistoryParser.parse(
                Self.output([
                    Self.record(objectID: "bbbb", parents: "", decoration: "grafted, HEAD -> main"),
                ])
            ).first
        )

        #expect(root.parentObjectIDs.isEmpty)
        #expect(root.isRoot)
        #expect(!root.isShallowBoundary)
        #expect(boundary.parentObjectIDs.isEmpty)
        #expect(boundary.isShallowBoundary)
        #expect(!boundary.isRoot)
        // `grafted` is not a Ref, so nothing may render it as though a branch were called that.
        #expect(boundary.refLabels.map(\.name) == ["HEAD", "main"])
    }

    @Test
    func readsEveryKindOfRefTheDecorationNames() {
        let refs = GitHistoryParser.refLabels(
            decoration: "HEAD -> main, tag: v1.0, origin/main, feature/origin/main",
            remoteBranchNames: ["origin/main"]
        )

        #expect(
            refs.labels == [
                HistoryRefLabel(name: "HEAD", kind: .head),
                HistoryRefLabel(name: "main", kind: .localBranch),
                HistoryRefLabel(name: "v1.0", kind: .tag),
                HistoryRefLabel(name: "origin/main", kind: .remoteBranch),
                // A slash is not what makes a Ref remote: only the Repository's own list is.
                HistoryRefLabel(name: "feature/origin/main", kind: .localBranch),
            ]
        )
        #expect(!refs.isShallowBoundary)
    }

    @Test
    func readsADetachedHeadAsHeadAlone() {
        let refs = GitHistoryParser.refLabels(decoration: "HEAD", remoteBranchNames: [])

        #expect(refs.labels == [HistoryRefLabel(name: "HEAD", kind: .head)])
    }

    @Test
    func readsNoRefsFromAnUndecoratedCommit() {
        #expect(GitHistoryParser.refLabels(decoration: "", remoteBranchNames: []).labels.isEmpty)
    }

    @Test
    func readsNothingFromNoOutput() throws {
        #expect(try GitHistoryParser.parse(Data()).isEmpty)
    }

    /// A record Colofa cannot read is refused rather than turned into a row with holes in it: a
    /// page that quietly dropped a Commit would read as a complete History.
    @Test(
        arguments: [
            "1111\u{0}1111\u{0}\u{0}Name\u{0}mail\u{0}1700000000\u{0}Name\u{0}mail",
            "1111\u{0}1111\u{0}\u{0}Name\u{0}mail\u{0}not-a-time\u{0}Name\u{0}mail"
                + "\u{0}1700000000\u{0}\u{0}Summary",
            "\u{0}1111\u{0}\u{0}Name\u{0}mail\u{0}1700000000\u{0}Name\u{0}mail"
                + "\u{0}1700000000\u{0}\u{0}Summary",
        ]
    )
    func refusesARecordItCannotRead(_ record: String) {
        #expect(throws: GitOutputParsingError.self) {
            try GitHistoryParser.parse(Data("\u{1e}\(record)\n".utf8))
        }
    }

    /// Git writes UTF-8, and content in another encoding is still shown rather than dropped.
    @Test
    func readsANameThatIsNotUTF8() throws {
        var data = Data("\u{1e}aaaa\u{0}aaaa\u{0}\u{0}".utf8)
        data.append(0xFF)
        data.append(
            Data("\u{0}mail\u{0}1700000000\u{0}Name\u{0}mail\u{0}1700000000\u{0}\u{0}S\n".utf8)
        )

        let commit = try #require(try GitHistoryParser.parse(data).first)
        #expect(!commit.authorName.isEmpty)
        #expect(commit.summary == "S")
    }

    private static func output(_ records: [String]) -> Data {
        Data(records.joined().utf8)
    }

    private static func record(
        objectID: String,
        abbreviated: String = "abbrev",
        parents: String = "0000",
        authorName: String = "Name",
        authorEmail: String = "mail@example.invalid",
        authoredAt: String = "1700000000",
        committerName: String = "Name",
        committerEmail: String = "mail@example.invalid",
        committedAt: String = "1700000000",
        decoration: String = "",
        summary: String = "Summary"
    ) -> String {
        let fields = [
            objectID, abbreviated, parents, authorName, authorEmail, authoredAt,
            committerName, committerEmail, committedAt, decoration, summary,
        ]
        return "\u{1e}" + fields.joined(separator: "\u{0}") + "\n"
    }
}
