////
//  CommitMessageDraft.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// What the user has typed into the Commit composer.
///
/// Amend is part of the draft rather than a separate flag because entering it replaces the
/// message, and leaving it has to give the user's own text back.
struct CommitMessageDraft: Equatable, Sendable {
    /// Where Git tooling starts shortening a Summary. Guidance only: Git accepts longer ones and
    /// so does Colofa.
    static let recommendedSummaryLength = 50

    var summary = ""
    var body = ""
    private(set) var isAmending = false
    private(set) var amendedCommitObjectID: String?

    /// The message being written before Amend replaced it with HEAD's, so leaving Amend does not
    /// discard the user's own text.
    private var replacedMessage: Message?

    private struct Message: Equatable, Sendable {
        let summary: String
        let body: String
    }

    var trimmedSummary: String {
        summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasSummary: Bool {
        !trimmedSummary.isEmpty
    }

    var exceedsRecommendedSummaryLength: Bool {
        trimmedSummary.count > Self.recommendedSummaryLength
    }

    /// The message exactly as Git should store it: Summary, then the body separated by the blank
    /// line Git expects between them.
    var message: String {
        trimmedBody.isEmpty ? trimmedSummary : "\(trimmedSummary)\n\n\(trimmedBody)\n"
    }

    mutating func beginAmending(with headCommit: RepositoryHeadCommit) {
        guard !isAmending else {
            return
        }
        replacedMessage = Message(summary: summary, body: body)
        summary = headCommit.summary
        body = headCommit.body
        amendedCommitObjectID = headCommit.objectID
        isAmending = true
    }

    mutating func endAmending() {
        guard isAmending else {
            return
        }
        summary = replacedMessage?.summary ?? ""
        body = replacedMessage?.body ?? ""
        replacedMessage = nil
        amendedCommitObjectID = nil
        isAmending = false
    }

    mutating func clear() {
        self = Self()
    }
}
