////
//  AskPassBoundaryIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin
import Foundation
import Testing
@testable import Colofa

/// How much may cross an AskPass channel, asserted over a real socket in both directions.
///
/// The limit is only a limit where a message that runs over is refused rather than read up to it.
/// Neither end can tell truncation from an ending on its own — a prompt has no length in front of
/// it and an answer ends when the connection closes — so the boundary has to be exercised where
/// the bytes actually travel rather than on a buffer a test assembled.
struct AskPassBoundaryIntegrationTests {
    /// A question that runs over what a question may occupy is refused whole rather than answered
    /// on the part of it that arrived. Reading to the limit and stopping would leave a prompt
    /// whose meaning is decided by text nobody saw — including, for a host key, the words that
    /// separate a key Colofa asks about from one it refuses outright.
    @Test
    func refusesAQuestionLargerThanAQuestionOverTheSocket() async throws {
        let responder = RecordingResponder(answering: AskedCredential.secret)
        let bridge = try GitAskPassBridge(
            helperURL: try askPassHelperURL(),
            responder: responder.responder
        )
        defer { bridge.stop() }
        let socketPath = try #require(bridge.environment[GitAskPassSocket.socketVariable])
        let token = try #require(bridge.environment[GitAskPassSocket.tokenVariable])

        let descriptor = try connectedSocket(to: socketPath)
        defer { close(descriptor) }
        let oversized = Self.request(
            token: token,
            occupying: GitAskPassMessage.maximumRequestSize + 1
        )
        writeAndFinish(oversized, to: descriptor)

        #expect(readUntilClosed(descriptor) == GitAskPassMessage.reply(.cancelled))
        #expect(await responder.recordedRequests().isEmpty)
    }

    /// The boundary is where it is documented to be: a question filling the limit exactly is a
    /// question, so the refusal above is about running over rather than about being long.
    @Test
    func answersAQuestionThatFillsTheLimitExactly() async throws {
        let responder = RecordingResponder(answering: AskedCredential.secret)
        let bridge = try GitAskPassBridge(
            helperURL: try askPassHelperURL(),
            responder: responder.responder
        )
        defer { bridge.stop() }
        let socketPath = try #require(bridge.environment[GitAskPassSocket.socketVariable])
        let token = try #require(bridge.environment[GitAskPassSocket.tokenVariable])

        let descriptor = try connectedSocket(to: socketPath)
        defer { close(descriptor) }
        writeAndFinish(
            Self.request(token: token, occupying: GitAskPassMessage.maximumRequestSize),
            to: descriptor
        )

        #expect(
            readUntilClosed(descriptor) == GitAskPassMessage.reply(.answer(AskedCredential.secret))
        )
        #expect(await responder.recordedRequests().count == 1)
    }

    /// The same boundary in the other direction. An answer that runs over is discarded rather than
    /// truncated and printed, because half a secret is still a secret Git would authenticate with
    /// — and failing to authenticate is not what an AskPass program declining looks like.
    @Test
    func refusesAnAnswerLargerThanTheChannelAllows() throws {
        let standIn = try StandInBridge(token: UUID().uuidString)
        let oversized = GitAskPassMessage.reply(
            .answer(String(repeating: "x", count: GitAskPassMessage.maximumRequestSize))
        )

        standIn.beginAnswering(with: oversized)
        let asked = try runAskPassHelper(
            prompt: AskedCredential.prompt,
            environment: standIn.environment
        )

        #expect(oversized.count > GitAskPassMessage.maximumRequestSize)
        #expect(asked.status != 0, "An answer that ran over was passed on to Git anyway")
        #expect(asked.output.isEmpty)
    }

    /// A request occupying exactly `size` bytes, padded inside the question so the padding is part
    /// of what the limit is about rather than of the format around it.
    private static func request(token: String, occupying size: Int) -> Data {
        let format = GitAskPassMessage.request(token: token, prompt: "").count
        return GitAskPassMessage.request(
            token: token,
            prompt: String(repeating: "x", count: size - format)
        )
    }
}
