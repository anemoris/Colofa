////
//  HistoryCommitDetailTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct HistoryCommitDetailTests {
    /// The message is split the way a Commit is read: the first line names it, and everything
    /// past the blank line Git writes is the rest of what it says.
    @Test
    func splitsAMessageIntoItsSummaryAndBody() {
        let detail = HistoryCommitDetail(
            objectID: "aaaa",
            message: "Add a file\n\nWhy it was added,\nover two lines.\n",
            changedFiles: []
        )

        #expect(detail.summary == "Add a file")
        #expect(detail.body == "Why it was added,\nover two lines.")
    }

    @Test
    func aMessageWithOnlyASummaryHasNoBody() {
        let detail = HistoryCommitDetail(objectID: "aaaa", message: "Add a file\n", changedFiles: [])

        #expect(detail.summary == "Add a file")
        #expect(detail.body.isEmpty)
    }

    /// Swift reads CRLF as a single Character, so a message written with CRLF holds no `\n` at
    /// all: split on one, the whole message reads as the Summary and the Commit appears to have
    /// no body.
    ///
    /// Such a message also arrives still carrying the newline `git log` ends its record with,
    /// because the `\r\n` it ends in is not the `\n` `GitHistoryReader` strips.
    @Test
    func aCRLFMessageSplitsIntoTheSameSummaryAndBodyAnLFMessageDoes() {
        let detail = HistoryCommitDetail(
            objectID: "aaaa",
            message: "Add a file\r\n\r\nWhy it was added,\r\nover two lines.\r\n",
            changedFiles: []
        )

        #expect(detail.summary == "Add a file")
        #expect(detail.body == "Why it was added,\r\nover two lines.")
    }

    /// The pane shows the message, so a Commit written with a leading space on its first line
    /// shows that space rather than the line Git would have tidied for a listing.
    @Test
    func aSummaryKeepsTheWhitespaceTheCommitHolds() {
        let detail = HistoryCommitDetail(
            objectID: "aaaa",
            message: "  Add a file\n\nWhy it was added.\n",
            changedFiles: []
        )

        #expect(detail.summary == "  Add a file")
    }

    /// The blank line Git writes is what goes, not the body's own leading whitespace: a message
    /// that opens its description with an indented line means that indentation.
    @Test
    func aBodyKeepsTheIndentationOfItsFirstLine() {
        let detail = HistoryCommitDetail(
            objectID: "aaaa",
            message: "Add a file\n\n    indented\nplain\n",
            changedFiles: []
        )

        #expect(detail.body == "    indented\nplain")
    }

    @Test
    func aBodyOfNothingButWhitespaceReadsAsNoBody() {
        let detail = HistoryCommitDetail(
            objectID: "aaaa",
            message: "Add a file\n\n   \n",
            changedFiles: []
        )

        #expect(detail.body.isEmpty)
    }

    /// A binary change reports no line counts rather than reporting zero, so it contributes
    /// nothing to the totals instead of hiding inside them.
    @Test
    func addsUpOnlyTheCountsGitReported() {
        let detail = HistoryCommitDetail(
            objectID: "aaaa",
            message: "Change\n",
            changedFiles: [
                DiffFileSummary(
                    oldPath: nil,
                    newPath: "a.txt",
                    stats: DiffStats(additions: 3, deletions: 1)
                ),
                DiffFileSummary(oldPath: nil, newPath: "image.bin", stats: nil),
            ]
        )

        #expect(detail.stats == DiffStats(additions: 3, deletions: 1))
    }

    @Test
    func aCommitIsComparedAgainstItsFirstParent() {
        let request = historyCommit(0, parents: ["p1", "p2"])
            .detailRequest(in: historyRepositoryURL)

        #expect(request.parentObjectID == "p1")
        #expect(request.diffSource == .commit(objectID: historyObjectID(0), parentObjectID: "p1"))
    }

    @Test
    func aCommitWithNoParentCarriesNoneIntoItsDiff() {
        let request = historyCommit(0, parents: []).detailRequest(in: historyRepositoryURL)

        #expect(request.parentObjectID == nil)
        #expect(request.diffSource == .commit(objectID: historyObjectID(0), parentObjectID: nil))
    }
}
