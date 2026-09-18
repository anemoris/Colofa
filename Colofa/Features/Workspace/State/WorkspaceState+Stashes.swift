////
//  WorkspaceState+Stashes.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Saving uncommitted work as a real Stash, and reading back what one holds.
///
/// Nothing here restores anything. Selecting a Stash is inspection: it reads what Git stored and
/// never writes to the index or the working tree, which is why the Diff it shows carries no Stage
/// action at all.
extension WorkspaceState {
    /// Everything that decides which list belongs on screen, including the Repository read: a
    /// Stash created, dropped, or applied elsewhere changes the list without changing which
    /// Repository is open.
    struct StashIdentity: Hashable, Sendable {
        let repositoryURL: URL
        let generation: Int
    }

    /// Which entry's saved paths are being read. The object ID is part of it because `stash@{0}`
    /// addresses a different entry once another Stash is pushed in front of it.
    struct StashDetailIdentity: Hashable, Sendable {
        let repositoryURL: URL
        let objectID: String
        let generation: Int
    }

    // MARK: - Selection

    var stashes: StashLoadState? { stashPresentation.state }

    var selectedStashID: String? {
        get { stashPresentation.selectedStashID }
        set { stashPresentation.selectedStashID = newValue }
    }

    var selectedStash: Stash? {
        guard let selectedStashID else {
            return nil
        }
        return stashPresentation.stashes?.first { $0.id == selectedStashID }
    }

    var stashDetail: StashDetailLoadState? { stashPresentation.detail }

    /// Which of the selected Stash's paths the Diff pane is reading.
    ///
    /// A Stash is browsed one file at a time, the same way a Commit is: the whole of what it
    /// saved is never read at once, so a size limit is reached by a file rather than by a Stash.
    var selectedStashFileID: String? {
        get { stashPresentation.selectedFileID }
        set { stashPresentation.selectedFileID = newValue }
    }

    var selectedStashFile: StashFile? {
        guard let selectedStashFileID else {
            return nil
        }
        return stashDetail?.detail?.file(selectedStashFileID)
    }

    // MARK: - Loading

    var stashIdentity: StashIdentity? {
        guard let repository else {
            return nil
        }
        return StashIdentity(
            repositoryURL: repository.rootURL,
            generation: repositoryGeneration
        )
    }

    var stashDetailIdentity: StashDetailIdentity? {
        guard let repository, let stash = selectedStash else {
            return nil
        }
        return StashDetailIdentity(
            repositoryURL: repository.rootURL,
            objectID: stash.objectID,
            generation: repositoryGeneration
        )
    }

    /// Reads every entry Git holds, or clears the pane when there is no Repository to ask.
    func loadStashes() async {
        guard let repository else {
            clearStashes()
            return
        }
        if repository.rootURL != stashPresentation.loadedRepositoryURL {
            stashPresentation.state = .loading
            stashPresentation.selectedStashID = nil
        } else if case .failed = stashPresentation.state {
            // Reload Stashes is the one read a user asks for by hand, and the failure it replaces
            // is the whole of what the pane is showing: without this it would sit unchanged until
            // the answer arrived, looking like a button that did nothing.
            stashPresentation.state = .loading
        }
        stashPresentation.loadedRepositoryURL = repository.rootURL

        stashPresentation.loadID += 1
        let loadID = stashPresentation.loadID
        do {
            let stashes = try await repositoryService.loadStashes(repository.rootURL)
            guard loadID == stashPresentation.loadID else {
                return
            }
            // Read before the list is replaced: afterwards the selected address names whatever
            // this read put at that position, which is the very confusion being reconciled away.
            let previousObjectID = selectedStash?.objectID
            stashPresentation.state = .loaded(stashes)
            reconcileStashSelection(in: stashes, previousObjectID: previousObjectID)
        } catch is CancellationError {
            // The Repository moved on. Whichever read replaced this one owns the pane now.
            return
        } catch {
            guard loadID == stashPresentation.loadID else {
                return
            }
            stashPresentation.state = .failed(Self.stashFailure(error))
            stashPresentation.selectedStashID = nil
        }
    }

    /// Reads the paths the selected Stash saved, which the list deliberately leaves unread.
    func loadStashDetail() async {
        guard let repository, let stash = selectedStash else {
            clearStashDetail()
            return
        }

        stashPresentation.detailLoadID += 1
        let loadID = stashPresentation.detailLoadID
        if stashDetail?.detail?.objectID != stash.objectID {
            stashPresentation.detail = .loading
        }

        do {
            let detail = try await repositoryService.loadStashDetail(
                stash.detailRequest(in: repository.rootURL)
            )
            guard loadID == stashPresentation.detailLoadID else {
                return
            }
            stashPresentation.detail = .loaded(detail)
            reconcileStashFileSelection(in: detail)
        } catch is CancellationError {
            return
        } catch {
            guard loadID == stashPresentation.detailLoadID else {
                return
            }
            stashPresentation.detail = .failed(Self.stashFailure(error))
        }
    }

    // MARK: - Creating one

    /// Whether the Stash sheet is on screen. Dismissing it by any route — Cancel, Escape, or
    /// clicking away — is the same as cancelling it, which is refused once Stash is running.
    var isCreatingStash: Bool {
        get { stashCreation != nil }
        set {
            if !newValue {
                cancelStashCreation()
            }
        }
    }

    /// Why the toolbar's and the menu's Stash cannot open the sheet, or `nil` when it can.
    ///
    /// Asked as though untracked files were included, because the sheet is where that option is
    /// chosen: a Repository whose only work is untracked has something to save, and refusing to
    /// open the one place that decides so would refuse it for a reason the user could not act on.
    var stashCreationUnavailabilityReason: StashCreationUnavailabilityReason? {
        StashCreationUnavailabilityReason.evaluate(
            repository: repository,
            includesUntrackedFiles: true,
            isMutating: !canMutateRepository
        )
    }

    var canBeginCreatingStash: Bool {
        stashCreationUnavailabilityReason == nil
    }

    /// Why the sheet's own Stash button cannot run, or `nil` when it can.
    ///
    /// Asked with the options as they stand, which is what makes an untracked-only Repository say
    /// that Include Untracked Files is the thing to turn on rather than sitting disabled in
    /// silence.
    var stashCreationRefusal: StashCreationUnavailabilityReason? {
        StashCreationUnavailabilityReason.evaluate(
            repository: repository,
            includesUntrackedFiles: stashCreation?.includesUntrackedFiles ?? false,
            isMutating: !canMutateRepository
        )
    }

    var canCreateStash: Bool {
        stashCreation != nil && stashCreationRefusal == nil
    }

    func beginCreatingStash() {
        guard canBeginCreatingStash else {
            return
        }
        stashCreation = StashCreationDraft()
    }

    /// Drops the pending Stash without running anything, which is what Cancel does.
    ///
    /// Refused while a command runs: a Stash already handed to Git runs to the end regardless,
    /// and a refusal arriving after the sheet was dropped would have nowhere to be shown.
    func cancelStashCreation() {
        guard !isPerformingMutation else {
            return
        }
        stashCreation = nil
    }

    /// Saves the Stash the sheet describes.
    ///
    /// A failure keeps the sheet open with Git's own words in it, the way New Branch does: the
    /// message and the two options are what the user would change, and an alert would take them
    /// away to say so.
    func createStash() async {
        guard let draft = stashCreation, canCreateStash else {
            return
        }
        stashCreation?.clearFailure()
        switch await runMutation(draft.arguments) {
        case .succeeded:
            stashCreation = nil
        case .unavailable:
            // Nothing ran, so the sheet stays for the user to press again.
            return
        case .failed(let error):
            stashCreation?.recordFailure(Self.stashFailureDetails(of: error))
        }
    }

    // MARK: - Reloads

    /// Drops whatever the pane held.
    ///
    /// It returns without writing anything when there is nothing to drop: an `@Observable` write
    /// invalidates the views reading it whether or not the value changed, and a Stashes pane with
    /// nothing in it must not redraw the window every time Colofa reloads.
    ///
    /// Not private: `publishRepository` calls it when the workspace moves to another Repository.
    func clearStashes() {
        guard stashPresentation.state != nil
            || stashPresentation.loadedRepositoryURL != nil
            || stashPresentation.selectedStashID != nil
            || stashPresentation.detail != nil
            || stashPresentation.selectedFileID != nil else {
            return
        }
        stashPresentation = stashPresentation.emptied()
    }

    /// Keeps the selection on an entry this read still reports.
    ///
    /// Matched by object ID rather than by address: creating or dropping a Stash renumbers the
    /// list, so `stash@{1}` after a reload is routinely a different entry from the one that was
    /// selected. An ID that now appears more than once — the same work saved twice produces the
    /// same Commit — names no single entry, so the selection is dropped rather than guessed at.
    private func reconcileStashSelection(in stashes: [Stash], previousObjectID: String?) {
        guard let previousObjectID else {
            if stashPresentation.selectedStashID != nil {
                stashPresentation.selectedStashID = nil
            }
            return
        }
        let matches = stashes.filter { $0.objectID == previousObjectID }
        stashPresentation.selectedStashID = matches.count == 1 ? matches[0].id : nil
    }

    /// Opens the Stash on a file rather than on nothing, and keeps the file the user was reading
    /// whenever this Stash saved it too.
    private func reconcileStashFileSelection(in detail: StashDetail) {
        if let selectedStashFileID, detail.file(selectedStashFileID) != nil {
            return
        }
        stashPresentation.selectedFileID = detail.files.first?.id
    }

    private func clearStashDetail() {
        guard stashDetail != nil || stashPresentation.selectedFileID != nil else {
            return
        }
        stashPresentation.detailLoadID += 1
        stashPresentation.detail = nil
        stashPresentation.selectedFileID = nil
    }

    private static func stashFailure(_ error: any Error) -> RepositoryOpenError {
        if let error = error as? RepositoryOpenError {
            return error
        }
        return .commandFailed(
            GitFailureDetails(command: "git stash", output: error.localizedDescription)
        )
    }

    /// Git's own sanitized words when it produced any, and Colofa's description of the error when
    /// Git never got far enough to write one.
    private static func stashFailureDetails(of error: RepositoryOpenError) -> GitFailureDetails {
        error.failureDetails
            ?? GitFailureDetails(command: "git stash", output: String(localized: error.message))
    }
}
