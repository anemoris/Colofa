////
//  WorkspaceState+Repository.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Publishing what one authoritative read reported.
///
/// Every read of the open Repository ends here, which is what makes the promise around one true:
/// nothing the window shows is state Colofa assumed. It is what Git answered, reconciled against
/// whatever was already on screen — a dialog whose subject has moved, a selection whose path is
/// gone, a Diff read from content that has changed underneath it.
extension WorkspaceState {
    func publishRepository(_ repository: RepositorySnapshot) {
        let isSameRepository = self.repository?.rootURL == repository.rootURL
        storePublishedRepository(repository)
        if !isSameRepository {
            // A message written for one Repository must not follow the user into another, and
            // neither may a New Branch dialog whose start point belongs to the previous one, nor
            // a Fetch Tags dialog: its remote was chosen from the previous Repository's remotes,
            // and confirming it here would contact a remote of this one that the user never saw.
            // A Push dialog goes for both of those reasons at once: its Branch, its remote, and
            // the object its lease expects all belong to the Repository being left behind. A
            // Delete Branch confirmation and a Merge confirmation go the same way: each names
            // branches of the Repository being left, which this one has by those names too. A
            // Stash sheet goes too: its options describe the work in the Repository being left.
            commitDraft.clear()
            clearStashes()
            branchCreation = nil
            branchDeletion = nil
            mergeDraft = nil
            tagFetchSelection = nil
            pushDialog = nil
            stashCreation = nil
            pendingFileAction = nil
            isConfirmingHistoryRewrite = false
            isShowingStaleAmendAlert = false
            isShowingStalePushAlert = false
            isShowingStaleBranchDeletionAlert = false
        } else {
            // The same Repository, read again. A dialog that survived that reload has to be
            // checked against it rather than trusted: what it showed is what its own confirmation
            // will act on, and only a comparison can say whether that is still the truth.
            reconcilePushDialog(against: repository)
            reconcileFileAction(against: repository)
            reconcileBranchDeletion(against: repository)
            if !isRewritingHead {
                reconcileAmendDraft()
            }
        }
        updateSelectedChange(for: repository)
        updateHistoryReference(for: repository, isSameRepository: isSameRepository)
        if !isSameRepository {
            // App-owned metadata, so it is read when a Repository arrives rather than on every
            // reload: a reload of the same Repository must not overwrite the time the Fetch that
            // started it just recorded.
            lastFetchDate = storedFetchDate(of: repository.rootURL)
        }
        repositoryFailure = nil
        guard !isUITesting else {
            return
        }
        userDefaults.set(
            repository.rootURL.normalizedFilePath,
            forKey: Self.lastRepositoryPathKey
        )
    }
}
