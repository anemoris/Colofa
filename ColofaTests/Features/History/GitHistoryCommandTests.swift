////
//  GitHistoryCommandTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct GitHistoryCommandTests {
    @Test
    func aPageWalksTopologicallyFromTheSelectedRef() {
        let arguments = GitHistoryCommand.page(
            for: HistoryPageRequest(
                repositoryURL: historyRepositoryURL,
                reference: .remoteBranch("origin/main")
            )
        ).arguments

        #expect(arguments.contains("--topo-order"))
        #expect(arguments.contains("refs/remotes/origin/main"))
        #expect(arguments.last == "--")
        #expect(arguments.contains("--format=\(GitHistoryCommand.recordFormat)"))
    }

    /// One record more than the page, because Load More has to be offered when Git reported
    /// something further rather than when a page happened to come back full.
    @Test
    func aPageAsksForOneRecordMoreThanItShows() {
        let arguments = GitHistoryCommand.page(
            for: HistoryPageRequest(
                repositoryURL: historyRepositoryURL,
                reference: .head,
                pageSize: 200
            )
        ).arguments

        #expect(arguments.contains("--max-count=201"))
    }

    @Test
    func aPageSkipsWhatGitAlreadyReported() {
        let arguments = GitHistoryCommand.page(
            for: HistoryPageRequest(
                repositoryURL: historyRepositoryURL,
                reference: .head,
                offset: 400,
                pageSize: 200
            )
        ).arguments

        #expect(arguments.contains("--skip=400"))
    }

    /// A Ref moves while the user pages, and `--skip` counted against a Ref that moved backwards
    /// walks past Commits that were never shown. Once the first page has resolved the Ref, every
    /// later page is asked for from that Commit instead.
    @Test
    func alaterPageWalksFromThePinnedCommitRatherThanTheRef() {
        let arguments = GitHistoryCommand.page(
            for: HistoryPageRequest(
                repositoryURL: historyRepositoryURL,
                reference: .localBranch("main"),
                offset: 200,
                tipObjectID: historyObjectID(0)
            )
        ).arguments

        #expect(arguments.contains(historyObjectID(0)))
        #expect(!arguments.contains("refs/heads/main"))
        #expect(arguments.contains("--skip=200"))
        #expect(arguments.last == "--")
    }

    /// Each of these appends output that is not part of the record being parsed, and any of them
    /// would turn a readable page into a parsing failure.
    @Test(arguments: ["--no-color", "--no-show-signature", "--no-notes", "--no-optional-locks"])
    func everyConfigurationThatWouldChangeTheOutputIsStated(_ option: String) {
        let page = GitHistoryCommand.page(
            for: HistoryPageRequest(repositoryURL: historyRepositoryURL, reference: .head)
        )
        let message = GitHistoryCommand.message(for: "0123456789")

        #expect(page.arguments.contains(option))
        #expect(message.arguments.contains(option))
    }

    @Test
    func aMessageIsReadRawForOneCommit() {
        let arguments = GitHistoryCommand.message(for: "0123456789abcdef").arguments

        #expect(arguments.contains("--max-count=1"))
        #expect(arguments.contains("--format=%B"))
        #expect(arguments.contains("0123456789abcdef"))
        #expect(arguments.last == "--")
    }

    /// The separator has to be a byte Git identities, subjects, and Ref names cannot contain, and
    /// the fields have to be separated by a different one.
    @Test
    func theRecordFormatSeparatesRecordsAndFieldsWithDifferentBytes() {
        #expect(GitHistoryCommand.recordFormat.hasPrefix("%x1e"))
        #expect(!GitHistoryCommand.recordFormat.contains("%x1e%x00"))
        #expect(GitHistoryCommand.recordFormat.components(separatedBy: "%x00").count == 11)
        // Times are read as UNIX timestamps, so no Repository setting or locale can reshape them.
        #expect(GitHistoryCommand.recordFormat.contains("%at"))
        #expect(GitHistoryCommand.recordFormat.contains("%ct"))
    }

    /// Both walks are Git's own answers to different questions, so the scope changes what is
    /// asked rather than what is kept from the answer.
    @Test
    func onlyTheFirstParentWalkFollowsTheRefsOwnLine() {
        let reachable = GitHistoryCommand.page(
            for: HistoryPageRequest(repositoryURL: historyRepositoryURL, reference: .head)
        ).arguments
        let firstParent = GitHistoryCommand.page(
            for: HistoryPageRequest(
                repositoryURL: historyRepositoryURL,
                reference: .head,
                scope: .firstParent
            )
        ).arguments

        #expect(!reachable.contains("--first-parent"))
        #expect(firstParent.contains("--first-parent"))
        #expect(firstParent.contains("--topo-order"))
        #expect(firstParent.last == "--")
    }
}
