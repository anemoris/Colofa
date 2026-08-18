////
//  WorkspaceState+History.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

extension WorkspaceState {
    /// Everything that decides which History belongs on screen, including the Repository read:
    /// a Fetch or a Commit moves a Ref without changing which Ref is selected.
    struct HistoryIdentity: Hashable, Sendable {
        let key: HistoryKey
        let scope: HistoryScope
        let generation: Int
    }

    struct CommitDetailIdentity: Hashable, Sendable {
        let repositoryURL: URL
        let objectID: String
        let generation: Int
    }

    // MARK: - Selection

    /// The sidebar's single selected row.
    ///
    /// Written through rather than stored directly, because selecting a Ref is also what puts
    /// History on screen: the two cannot disagree.
    var sidebarSelection: SidebarSelection {
        get { storedSidebarSelection }
        set { select(newValue) }
    }

    var selectedSection: WorkspaceSection {
        get {
            switch storedSidebarSelection {
            case .section(let section): section
            case .reference: .history
            }
        }
        set { storedSidebarSelection = .section(newValue) }
    }

    func select(_ selection: SidebarSelection) {
        storedSidebarSelection = selection
        if case .reference(let reference) = selection {
            historyPresentation.reference = reference
        }
    }

    /// The Ref whose History is on screen.
    var historyReference: GitReference { historyPresentation.reference }

    var history: HistoryLoadState? { historyPresentation.state }

    var historyPageFailure: RepositoryOpenError? { historyPresentation.pageFailure }

    var commitDetail: CommitDetailLoadState? { historyPresentation.commitDetail }

    var selectedCommitID: String? {
        get { historyPresentation.selectedCommitID }
        set { historyPresentation.selectedCommitID = newValue }
    }

    /// Which of the selected Commit's files the Diff pane is reading.
    ///
    /// A Commit is browsed one file at a time, the same way a working-tree Change is: the whole
    /// Commit's patch is never read, so a large Commit stays browsable and a size limit is
    /// reached by a file rather than by a Commit.
    var selectedCommitFileID: String? {
        get { historyPresentation.selectedFileID }
        set { historyPresentation.selectedFileID = newValue }
    }

    var selectedCommitFile: DiffFileSummary? {
        guard let selectedCommitFileID else {
            return nil
        }
        return commitDetail?.detail?.file(selectedCommitFileID)
    }

    var selectedCommit: HistoryCommit? {
        guard let selectedCommitID else {
            return nil
        }
        return historyPresentation.timeline?.commit(selectedCommitID)
    }

    // MARK: - Loading

    var historyIdentity: HistoryIdentity? {
        guard let repository else {
            return nil
        }
        return HistoryIdentity(
            key: HistoryKey(repositoryURL: repository.rootURL, reference: historyReference),
            scope: historyScope,
            generation: repositoryGeneration
        )
    }

    var commitDetailIdentity: CommitDetailIdentity? {
        guard let repository, let selectedCommitID else {
            return nil
        }
        return CommitDetailIdentity(
            repositoryURL: repository.rootURL,
            objectID: selectedCommitID,
            generation: repositoryGeneration
        )
    }

    /// Reads the first page of the selected Ref's History, or as many pages as were already
    /// loaded when this is a reload of the very same Ref.
    ///
    /// A reload asks for everything at once rather than page by page, so a Refresh gives back the
    /// History the user had scrolled to instead of dropping them at the top of it.
    func loadHistory() async {
        guard let repository else {
            clearHistory()
            return
        }
        let key = HistoryKey(repositoryURL: repository.rootURL, reference: historyReference)
        if case .unbornBranch = repository.head, historyReference == .head {
            reportUnbornHistory(at: key)
            return
        }

        // A different Ref is a different History, so nothing it selected carries over. A
        // different walk is the same History read another way: the Commit the user was reading
        // keeps its selection whenever the new walk still reaches it.
        if key != historyPresentation.loadedKey {
            historyPresentation.selectedCommitID = nil
        }
        if key != historyPresentation.loadedKey || historyScope != historyPresentation.loadedScope {
            historyPresentation.state = .loading
            historyPresentation.pageCount = 1
        }
        historyPresentation.loadedKey = key
        historyPresentation.loadedScope = historyScope
        historyPresentation.pageFailure = nil

        historyPresentation.loadID += 1
        let loadID = historyPresentation.loadID
        do {
            let page = try await repositoryService.loadHistory(
                HistoryPageRequest(
                    repositoryURL: key.repositoryURL,
                    reference: key.reference,
                    scope: historyScope,
                    pageSize: HistoryPageRequest.standardPageSize * historyPresentation.pageCount,
                    remoteBranchNames: Set(repository.remoteBranches)
                )
            )
            guard loadID == historyPresentation.loadID else {
                return
            }
            let timeline = HistoryTimeline(page: page)
            historyPresentation.state = .loaded(timeline)
            reconcileCommitSelection(in: timeline)
        } catch is CancellationError {
            // The Ref moved on. Whichever read replaced this one owns the pane now.
            return
        } catch {
            guard loadID == historyPresentation.loadID else {
                return
            }
            historyPresentation.state = .failed(Self.historyFailure(error))
            historyPresentation.selectedCommitID = nil
        }
    }

    /// Appends the next page. The offset is what Git already reported rather than what is on
    /// screen, so a Commit that arrived twice cannot make the walk step over the next one.
    func loadMoreHistory() async {
        guard let repository,
              var timeline = historyPresentation.timeline,
              timeline.hasMore,
              !timeline.isLoadingMore else {
            return
        }
        timeline.isLoadingMore = true
        historyPresentation.state = .loaded(timeline)
        historyPresentation.pageFailure = nil
        let loadID = historyPresentation.loadID

        do {
            let page = try await repositoryService.loadHistory(
                HistoryPageRequest(
                    repositoryURL: repository.rootURL,
                    reference: historyReference,
                    scope: historyScope,
                    offset: timeline.reportedCount,
                    remoteBranchNames: Set(repository.remoteBranches)
                )
            )
            guard loadID == historyPresentation.loadID,
                  var loaded = historyPresentation.timeline else {
                return
            }
            loaded.append(page)
            loaded.isLoadingMore = false
            historyPresentation.state = .loaded(loaded)
            historyPresentation.pageCount += 1
        } catch is CancellationError {
            finishLoadingMore(loadID: loadID, failure: nil)
        } catch {
            // The pages already read stay on screen: a page that failed to arrive is a reason to
            // offer the read again, not a reason to take back the History that did arrive.
            finishLoadingMore(loadID: loadID, failure: Self.historyFailure(error))
        }
    }

    /// Reads the message and changed paths of the selected Commit, which a page leaves unread.
    func loadCommitDetail() async {
        guard let repository, let commit = selectedCommit else {
            clearCommitDetail()
            return
        }

        historyPresentation.commitDetailLoadID += 1
        let loadID = historyPresentation.commitDetailLoadID
        if commitDetail?.detail?.objectID != commit.objectID {
            historyPresentation.commitDetail = .loading
        }

        do {
            let detail = try await repositoryService.loadCommitDetail(
                commit.detailRequest(in: repository.rootURL)
            )
            guard loadID == historyPresentation.commitDetailLoadID else {
                return
            }
            historyPresentation.commitDetail = .loaded(detail)
            reconcileFileSelection(in: detail)
        } catch is CancellationError {
            return
        } catch {
            guard loadID == historyPresentation.commitDetailLoadID else {
                return
            }
            historyPresentation.commitDetail = .failed(Self.historyFailure(error))
        }
    }

    var canLoadMoreHistory: Bool {
        guard let timeline = historyPresentation.timeline else {
            return false
        }
        return timeline.hasMore && !timeline.isLoadingMore
    }

    // MARK: - Copying

    /// The full SHA of the selected Commit. Colofa copies what Git stored, never the shortened
    /// form a row happens to show.
    var copyableCommitObjectID: String? {
        selectedCommit?.objectID
    }

    /// The branch the selected Ref names, which a tag and a Detached HEAD do not have.
    var copyableBranchName: String? {
        branchName(of: historyReference)
    }

    /// The branch `reference` names. HEAD names whichever branch it currently points at, and
    /// names nothing at all while it is detached or unborn.
    func branchName(of reference: GitReference) -> String? {
        if let name = reference.branchName {
            return name
        }
        guard reference == .head, case .branch(let name) = repository?.head else {
            return nil
        }
        return name
    }

    func copyCommitObjectID() {
        guard let copyableCommitObjectID else {
            return
        }
        pasteboard.write(copyableCommitObjectID)
    }

    func copyBranchName() {
        copyBranchName(of: historyReference)
    }

    func copyBranchName(of reference: GitReference) {
        guard let name = branchName(of: reference) else {
            return
        }
        pasteboard.write(name)
    }

    // MARK: - Reloads

    /// Keeps the selected Ref pointing at something the Repository still reports.
    ///
    /// A Ref that is gone — deleted, pruned, or belonging to a Repository that was replaced —
    /// falls back to HEAD, which every Repository has. The sidebar row moves with it rather than
    /// staying highlighted on a Ref that no longer exists.
    ///
    /// Not private: `publishRepository` calls it as each authoritative read lands.
    func updateHistoryReference(for repository: RepositorySnapshot, isSameRepository: Bool) {
        if isSameRepository, historyReference.exists(in: repository.references) {
            return
        }
        historyPresentation.reference = .head
        if case .reference = storedSidebarSelection {
            storedSidebarSelection = .reference(.head)
        }
    }

    /// Nothing is reachable from an Unborn Branch, and asking Git to walk from one is an error
    /// rather than an answer. It is a state, so it is reported as one and Git is never asked.
    private func reportUnbornHistory(at key: HistoryKey) {
        historyPresentation.loadID += 1
        historyPresentation.pageFailure = nil
        historyPresentation.loadedKey = key
        historyPresentation.loadedScope = historyScope
        historyPresentation.selectedCommitID = nil
        historyPresentation.state = .unborn
    }

    private func finishLoadingMore(loadID: Int, failure: RepositoryOpenError?) {
        guard loadID == historyPresentation.loadID,
              var timeline = historyPresentation.timeline else {
            return
        }
        timeline.isLoadingMore = false
        historyPresentation.state = .loaded(timeline)
        historyPresentation.pageFailure = failure
    }

    /// Keeps the Commit selection on something this Ref still reaches.
    ///
    /// Selecting a tag selects the Commit it names, which is where the walk starts. Every other
    /// Ref keeps whatever the user chose while it is still reachable, and otherwise selects
    /// nothing rather than silently landing on a different Commit.
    private func reconcileCommitSelection(in timeline: HistoryTimeline) {
        if let selectedCommitID, timeline.contains(selectedCommitID) {
            return
        }
        if case .tag = historyReference {
            historyPresentation.selectedCommitID = timeline.commits.first?.objectID
            return
        }
        historyPresentation.selectedCommitID = nil
    }

    /// Drops whatever the pane held.
    ///
    /// It returns without writing anything when there is nothing to drop: an `@Observable` write
    /// invalidates the views reading it whether or not the value changed, and a History pane with
    /// nothing in it must not redraw the window every time Colofa reloads.
    private func clearHistory() {
        guard historyPresentation.state != nil
            || historyPresentation.loadedKey != nil
            || historyPresentation.loadedScope != nil
            || historyPresentation.selectedCommitID != nil else {
            return
        }
        historyPresentation = historyPresentation.emptied(for: historyReference)
    }

    /// Opens the Commit on a file rather than on nothing, and keeps the file the user was reading
    /// whenever this Commit changed it too.
    private func reconcileFileSelection(in detail: HistoryCommitDetail) {
        if let selectedCommitFileID, detail.file(selectedCommitFileID) != nil {
            return
        }
        historyPresentation.selectedFileID = detail.changedFiles.first?.id
    }

    private func clearCommitDetail() {
        guard commitDetail != nil || historyPresentation.selectedFileID != nil else {
            return
        }
        historyPresentation.commitDetailLoadID += 1
        historyPresentation.commitDetail = nil
        historyPresentation.selectedFileID = nil
    }

    private static func historyFailure(_ error: any Error) -> RepositoryOpenError {
        if let error = error as? RepositoryOpenError {
            return error
        }
        return .commandFailed(
            GitFailureDetails(command: "git log", output: error.localizedDescription)
        )
    }
}
