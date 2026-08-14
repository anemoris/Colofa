////
//  RepositoryHeadCommit.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

/// The commit HEAD currently points at, as far as Amend needs to know it.
///
/// Absent on an Unborn Branch, where there is nothing to amend.
struct RepositoryHeadCommit: Equatable, Sendable {
    /// The object ID that makes an Amend draft belong to one exact HEAD.
    let objectID: String

    /// The message's first line, which prefills the composer's Summary when entering Amend.
    let summary: String

    /// Everything after the Summary, already stripped of the blank line Git inserts between them.
    let body: String

    /// True when a remote-tracking ref contains this commit, which makes Amend a rewrite of
    /// history someone else may already have.
    ///
    /// Read from the remote-tracking refs this machine already has, so it is only as current as
    /// the last Fetch: a Commit pushed from elsewhere since then still reads as unpublished.
    let isPublished: Bool

    /// True when Summary and Description cannot reproduce this message byte for byte, so
    /// committing the prefilled draft would rewrite its formatting.
    ///
    /// Git's own Summary is every line before the first blank one, joined by spaces, so a message
    /// whose first line is not followed by a blank line cannot survive a two-field composer.
    let amendReformatsMessage: Bool

    nonisolated init(
        objectID: String,
        summary: String,
        body: String = "",
        isPublished: Bool = false,
        amendReformatsMessage: Bool = false
    ) {
        self.objectID = objectID
        self.summary = summary
        self.body = body
        self.isPublished = isPublished
        self.amendReformatsMessage = amendReformatsMessage
    }
}
