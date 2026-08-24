////
//  GitAskPassMessageTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What crosses an AskPass channel, and everything the receiving end refuses to read as a
/// question.
struct GitAskPassMessageTests {
    private static let token = "89C4A6E0-1F2B-4C3D-8E5F-6A7B8C9D0E1F"

    @Test
    func carriesTheTokenAndTheQuestionAndNothingElse() throws {
        let data = GitAskPassMessage.request(
            token: Self.token,
            prompt: "Password for 'https://github.example': "
        )
        let message = try #require(GitAskPassMessage.parseRequest(data))

        #expect(message.token == Self.token)
        #expect(message.prompt == "Password for 'https://github.example': ")
    }

    /// A host key question is several lines, and every one of them has to survive the crossing.
    @Test
    func carriesAQuestionThatSpansSeveralLines() throws {
        let prompt = """
            The authenticity of host 'github.example (203.0.113.9)' can't be established.
            ED25519 key fingerprint is SHA256:abc.
            Are you sure you want to continue connecting (yes/no/[fingerprint])?
            """
        let message = try #require(
            GitAskPassMessage.parseRequest(
                GitAskPassMessage.request(token: Self.token, prompt: prompt)
            )
        )

        #expect(message.prompt == prompt)
    }

    /// Anything not speaking this format is not a question, whoever sent it.
    @Test
    func refusesWhatIsNotAQuestion() {
        #expect(GitAskPassMessage.parseRequest(Data()) == nil)
        #expect(GitAskPassMessage.parseRequest(Data("hello".utf8)) == nil)
        #expect(GitAskPassMessage.parseRequest(Data("colofa-askpass-9\ntoken\n?".utf8)) == nil)
        #expect(GitAskPassMessage.parseRequest(Data("colofa-askpass-1\n\n?".utf8)) == nil)
        #expect(GitAskPassMessage.parseRequest(Data("colofa-askpass-1\ntoken".utf8)) == nil)
    }

    /// A question larger than a question is not read at all, because reading it would be reading
    /// whatever a stranger decided to send.
    @Test
    func refusesAQuestionLargerThanAQuestion() {
        let oversized = GitAskPassMessage.request(
            token: Self.token,
            prompt: String(repeating: "x", count: GitAskPassMessage.maximumRequestSize)
        )

        #expect(oversized.count > GitAskPassMessage.maximumRequestSize)
        #expect(GitAskPassMessage.parseRequest(oversized) == nil)
    }

    /// An empty password and no password at all are different answers, so the reply says which.
    @Test
    func tellsAnEmptyAnswerApartFromNoAnswer() {
        #expect(
            GitAskPassMessage.parseReply(GitAskPassMessage.reply(.answer(""))) == .answer("")
        )
        #expect(GitAskPassMessage.parseReply(GitAskPassMessage.reply(.cancelled)) == .cancelled)
    }

    @Test
    func carriesAnAnswerBackUnchanged() {
        let secret = "hunter2 \n with everything in it"

        #expect(
            GitAskPassMessage.parseReply(GitAskPassMessage.reply(.answer(secret)))
                == .answer(secret)
        )
    }

    /// A channel torn down while a question was open sends nothing at all, and the AskPass
    /// program has to read that as the cancellation it is rather than as an empty secret.
    @Test
    func readsSilenceAsCancellation() {
        #expect(GitAskPassMessage.parseReply(Data()) == .cancelled)
    }
}
