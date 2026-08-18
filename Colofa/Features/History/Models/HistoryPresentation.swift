////
//  HistoryPresentation.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One Ref's History inside one Repository.
///
/// Both halves matter: a branch called `main` in another Repository is a different History that
/// happens to share a name, so neither the loaded pages nor the selected Commit carries over.
nonisolated struct HistoryKey: Hashable, Sendable {
    let repositoryURL: URL
    let reference: GitReference
}

/// Everything the History pane is showing, kept as one value the History extension owns.
///
/// Grouped rather than spread across the Store because these only ever change together: a Ref
/// that moved invalidates the pages, the page depth, the failure, and the selected Commit at
/// once.
nonisolated struct HistoryPresentation: Equatable, Sendable {
    /// The Ref History is read from. Selecting one is inspection: it never moves HEAD.
    var reference = GitReference.head
    var selectedCommitID: String?
    var state: HistoryLoadState?
    var loadedKey: HistoryKey?

    /// The walk the loaded pages came from. An offset counted in one walk means nothing in the
    /// other, so changing it starts the paging over.
    var loadedScope: HistoryScope?

    /// A Load More that failed. The pages already read stay on screen beside it, so the offer to
    /// try again explains itself rather than replacing the History it was made about.
    var pageFailure: RepositoryOpenError?

    /// How many standard pages are loaded. A reload asks for all of them at once, so a Refresh
    /// gives back the History the user had scrolled to rather than its first page.
    var pageCount = 1

    var loadID = 0
    var commitDetail: CommitDetailLoadState?

    /// Which of the selected Commit's files the Diff pane is reading, by `DiffFileSummary.id`.
    var selectedFileID: String?
    var commitDetailLoadID = 0

    var timeline: HistoryTimeline? { state?.timeline }

    /// The same pane holding nothing, ready to read `reference`.
    ///
    /// Both load IDs carry on from where they were rather than starting over, so neither read
    /// can be overtaken by one already in flight for the previous Ref: an ID reset to zero is
    /// handed out again by the next read, and the stale answer holding it would land in the pane
    /// this emptied.
    func emptied(for reference: GitReference) -> Self {
        Self(
            reference: reference,
            loadID: loadID + 1,
            commitDetailLoadID: commitDetailLoadID + 1
        )
    }
}
