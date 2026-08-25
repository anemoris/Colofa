////
//  GitAskPassMessage.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What travels over an AskPass channel, in both directions.
///
/// The channel carries one question and one answer and nothing else — no Repository, no command,
/// no identity — because everything else about the operation is already on the side that opened
/// it. Keeping the format here rather than inside either end is what lets it be read as a whole:
/// the bridge and the AskPass program are separate processes, and a format described twice is a
/// format that can disagree with itself.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: the AskPass
/// program has no main actor at all, and the bridge reads this off a socket.
nonisolated enum GitAskPassMessage {

    /// Names the format so a connection speaking anything else is refused rather than guessed at.
    static let version = "colofa-askpass-1"

    /// What one message may occupy, in either direction. A prompt is a line or a host key
    /// warning and an answer is a secret; anything larger is neither, and reading it would be
    /// reading whatever a stranger chose to send.
    ///
    /// Both ends refuse a message that runs over rather than reading up to here and stopping.
    /// A truncated question is a question whose meaning is decided by text nobody saw, and a
    /// truncated answer is a secret Git would go on to authenticate with.
    static let maximumRequestSize = 8 * 1_024

    /// One question, addressed with the token of the operation it belongs to.
    static func request(token: String, prompt: String) -> Data {
        Data("\(version)\n\(token)\n\(prompt)".utf8)
    }

    /// The token and question `data` carries, or `nil` when it is not a question at all.
    ///
    /// - Returns: The token exactly as sent, so the caller compares it rather than trusting it.
    static func parseRequest(_ data: Data) -> (token: String, prompt: String)? {
        guard data.count <= maximumRequestSize else {
            return nil
        }
        let lines = String(gitBytes: data)
            .split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
        guard lines.count == 3, lines[0] == version, !lines[1].isEmpty else {
            return nil
        }
        return (String(lines[1]), String(lines[2]))
    }

    /// One answer. A cancelled prompt is answered explicitly rather than by silence, so an empty
    /// password stays tellable apart from no password at all.
    static func reply(_ response: AuthenticationResponse) -> Data {
        guard let text = response.text else {
            return Data(cancelledMarker.utf8)
        }
        return Data("\(answerMarker)\(text)".utf8)
    }

    /// What the AskPass program was told to answer. A reply that never arrived — because the
    /// bridge was torn down while the question was open — reads as the cancellation it was.
    static func parseReply(_ data: Data) -> AuthenticationResponse {
        let reply = String(gitBytes: data)
        guard reply.hasPrefix(answerMarker) else {
            return .cancelled
        }
        return .answer(String(reply.dropFirst()))
    }

    private static let answerMarker = "+"
    private static let cancelledMarker = "-"
}
