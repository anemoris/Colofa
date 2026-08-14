////
//  GitHeadCommitReaderTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

struct GitHeadCommitReaderTests {
    /// One HEAD message and what the composer is expected to make of it.
    ///
    /// `message` is the Commit's own bytes, exactly as Git stores them; the record terminator
    /// `git log` adds is applied when the case is turned into reader input.
    struct MessageCase: Sendable, CustomTestStringConvertible {
        let name: String
        let message: String
        let summary: String
        let body: String
        let reformats: Bool

        var testDescription: String { name }
    }

    /// `nonisolated` because the project defaults to Main Actor isolation while Swift Testing
    /// reads a parameterized test's arguments from outside the actor.
    nonisolated static let messageCases = [
        MessageCase(
            name: "summary only",
            message: "Summary\n",
            summary: "Summary",
            body: "",
            reformats: false
        ),
        MessageCase(
            name: "summary and body",
            message: "Summary\n\nBody\n",
            summary: "Summary",
            body: "Body",
            reformats: false
        ),
        MessageCase(
            name: "blank lines inside the body are kept",
            message: "Summary\n\nFirst paragraph.\n\nSecond paragraph.\n",
            summary: "Summary",
            body: "First paragraph.\n\nSecond paragraph.",
            reformats: false
        ),
        // Git's own `%s` would hand back "line one line two" for this one.
        MessageCase(
            name: "multi-line subject",
            message: "line one\nline two\n\nreal body\n",
            summary: "line one",
            body: "line two\n\nreal body",
            reformats: true
        ),
        MessageCase(
            name: "indented body",
            message: "Summary\n\n    indented\n",
            summary: "Summary",
            body: "indented",
            reformats: true
        ),
        // Git's default `whitespace` cleanup keeps leading spaces on a line.
        MessageCase(
            name: "leading spaces on the subject",
            message: "  Leading spaces\n",
            summary: "Leading spaces",
            body: "",
            reformats: true
        ),
        MessageCase(
            name: "trailing whitespace on the subject",
            message: "Summary   \n\nBody\n",
            summary: "Summary",
            body: "Body",
            reformats: true
        ),
        // A verbatim cleanup keeps trailing blank lines that an Amend would drop.
        MessageCase(
            name: "trailing blank lines",
            message: "Summary\n\nBody\n\n\n",
            summary: "Summary",
            body: "Body",
            reformats: true
        ),
        // Trimming the body only reaches its ends; Git's cleanup reaches every line.
        MessageCase(
            name: "trailing whitespace inside the body",
            message: "Summary\n\nFirst line   \nSecond\n",
            summary: "Summary",
            body: "First line   \nSecond",
            reformats: true
        ),
        MessageCase(
            name: "consecutive blank lines inside the body",
            message: "Summary\n\nFirst\n\n\nSecond\n",
            summary: "Summary",
            body: "First\n\n\nSecond",
            reformats: true
        ),
        MessageCase(
            name: "no trailing newline at all",
            message: "Summary",
            summary: "Summary",
            body: "",
            reformats: true
        ),
    ]

    @Test(arguments: messageCases)
    func readsTheSummaryBodyAndWhetherAnAmendWouldReformatIt(messageCase: MessageCase) throws {
        let commit = try #require(
            GitHeadCommitReader.parse(record(messageCase.message), isPublished: false)
        )

        #expect(commit.objectID == "abc123")
        #expect(commit.summary == messageCase.summary)
        #expect(commit.body == messageCase.body)
        #expect(commit.amendReformatsMessage == messageCase.reformats)
    }

    /// The verdict is only as good as the cleanup it models, and only real Git can settle that.
    /// `AmendIntegrationTests.amendReformatsMessageAgreesWithWhatGitStores` runs every case above
    /// through an actual Amend; asserting it here against the same model would prove nothing.
    @Test(arguments: messageCases)
    func theSummaryAndDescriptionAreWhatTheComposerWouldOpen(messageCase: MessageCase) throws {
        let commit = try #require(
            GitHeadCommitReader.parse(record(messageCase.message), isPublished: false)
        )
        var draft = CommitMessageDraft()
        draft.beginAmending(with: commit)

        #expect(draft.summary == messageCase.summary)
        #expect(draft.body == messageCase.body)
    }

    @Test
    func readsTheObjectIDAndPublishedState() throws {
        let commit = record("Summary\n")
        let published = try #require(GitHeadCommitReader.parse(commit, isPublished: true))
        let unpublished = try #require(GitHeadCommitReader.parse(commit, isPublished: false))

        #expect(published.objectID == "abc123")
        #expect(published.isPublished)
        #expect(!unpublished.isPublished)
    }

    @Test
    func rejectsMissingFieldsAndNonUTF8Messages() {
        #expect(GitHeadCommitReader.parse(Data("abc123".utf8), isPublished: false) == nil)
        #expect(GitHeadCommitReader.parse(Data("\0Summary\n".utf8), isPublished: false) == nil)
        #expect(
            GitHeadCommitReader.parse(Data([0x61, 0x62, 0x63, 0, 0xFF]), isPublished: false) == nil
        )
    }

    /// The object ID, a NUL, the message, and the newline `git log` terminates the record with.
    private func record(_ message: String) -> Data {
        Data("abc123\0\(message)\n".utf8)
    }
}
