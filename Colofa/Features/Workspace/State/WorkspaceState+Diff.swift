////
//  WorkspaceState+Diff.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

extension WorkspaceState {
    /// Everything that decides which patch belongs on screen.
    ///
    /// The Change's kind is part of it because the same path can become a different comparison —
    /// a modification that becomes a deletion — and the Repository read is part of it because a
    /// file's content can change without its entry in the Repository doing so.
    struct DiffIdentity: Hashable, Sendable {
        let key: DiffKey
        let kind: RepositoryChangeKind?
        let generation: Int
    }

    /// What the Diff pane is being asked for, before anything is read.
    ///
    /// A Conflict is neither a patch nor an absence of one: Git describes it as a combined Diff
    /// of every side, which is not a review Colofa can honestly present, so it is a target of its
    /// own rather than a load that fails.
    private enum DiffTarget {
        case none
        case conflicted
        /// - Parameter path: Where the comparison is on disk, when it is about one path. A Commit
        ///   is about every path it touched, so it has none.
        case patch(DiffKey, path: String?, kind: RepositoryChangeKind?)
    }

    /// One comparison inside one Repository.
    ///
    /// The Repository is part of it because the same path is a different file in another
    /// Repository: neither the patch already on screen nor a confirmation the user gave for it
    /// carries over when the workspace moves to a Repository that happens to report the same
    /// path.
    struct DiffKey: Hashable, Sendable {
        let repositoryURL: URL
        let source: DiffSource
    }

    var diffIdentity: DiffIdentity? {
        guard case .patch(let key, _, let kind) = diffTarget else {
            return nil
        }
        return DiffIdentity(key: key, kind: kind, generation: repositoryGeneration)
    }

    /// What the current selection asks the Diff pane for, in whichever section owns it.
    ///
    /// Changes select a path, History selects a Commit, and both end in the same read-only
    /// presentation — the difference is only what Git is asked to compare.
    private var diffTarget: DiffTarget {
        guard let repository else {
            return .none
        }
        switch selectedSection {
        case .changes:
            guard let selection = selectedChange,
                  let change = change(for: selection) else {
                return .none
            }
            // An unmerged path has no two-sided comparison to show until it is resolved.
            guard !change.isConflict else {
                return .conflicted
            }
            return .patch(
                DiffKey(
                    repositoryURL: repository.rootURL,
                    source: DiffSource(change: change, isStaged: selection.isStaged)
                ),
                path: selection.path,
                kind: change.kind
            )
        case .history:
            // One file of the Commit, not the whole of it: the selection names the file, the
            // same way it names a path in Changes.
            guard let commit = selectedCommit, let file = selectedCommitFile else {
                return .none
            }
            return .patch(
                DiffKey(
                    repositoryURL: repository.rootURL,
                    source: .commit(
                        objectID: commit.objectID,
                        parentObjectID: commit.comparisonParentObjectID,
                        paths: file.gitPathspecs
                    )
                ),
                path: file.newPath,
                kind: nil
            )
        case .stashes:
            return .none
        }
    }

    /// Reads the patch for the current selection, or clears the pane when there is nothing to
    /// read. A selection that disappeared leaves no Diff behind.
    func loadDiff() async {
        switch diffTarget {
        case .none:
            clearDiff()
        case .conflicted:
            clearDiff(showing: .conflicted)
        case .patch(let key, let path, let kind):
            if key != loadedDiffKey {
                confirmedDiffKey = nil
            }
            // A path whose Change became a different one — a modification that became a deletion
            // — keeps its source but no longer describes the same comparison, so the previous
            // patch is cleared rather than left up while the new one is read. Re-reading the same
            // Change after an ordinary reload is what must not flicker.
            let describesTheSameChange = key == loadedDiffKey && kind == loadedDiffKind
            loadedDiffKind = kind
            await load(key, path: path, showsLoading: !describesTheSameChange)
        }
    }

    /// Renders a patch above an automatic limit after the user asked for it. The hard limits
    /// still apply: this raises the bound reading stops at rather than removing one.
    func loadDiffAnyway() async {
        // What the offer is answered with is read for what the workspace is on now, not for what
        // it was on when the offer was made. The target is rebuilt from the current Repository
        // and selection and has to be the very one the offer was made for: a selection that moved
        // while the offer stood — before its own read has run — takes the offer with it, rather
        // than confirming the previous comparison against the new one.
        guard case .confirmationRequired = diff,
              case .patch(let key, let path, _) = diffTarget,
              key == loadedDiffKey else {
            return
        }
        confirmedDiffKey = key
        await load(key, path: path, showsLoading: true)
    }

    /// Drops whatever the pane held, optionally leaving one state in its place.
    ///
    /// It returns without writing anything when there is nothing to drop. Every authoritative
    /// Repository read asks the pane to reconsider, and an `@Observable` write invalidates the
    /// views reading it whether or not the value changed — a Diff pane with nothing in it must
    /// not redraw the window every time Colofa reloads.
    private func clearDiff(showing state: DiffLoadState? = nil) {
        guard diff != state || loadedDiffKey != nil || diffFileURL != nil
            || loadedDiffKind != nil else {
            return
        }
        // A new load must not be overtaken by one already in flight for the previous selection.
        diffLoadID += 1
        diff = state
        diffFileURL = nil
        loadedDiffKey = nil
        confirmedDiffKey = nil
        loadedDiffKind = nil
    }

    private func load(
        _ key: DiffKey,
        path: String?,
        showsLoading: Bool
    ) async {
        diffLoadID += 1
        let loadID = diffLoadID
        if showsLoading {
            diff = .loading
        }
        loadedDiffKey = key
        if diffFileURL != nil {
            diffFileURL = nil
        }

        let request = DiffLoadRequest(
            source: key.source,
            repositoryURL: key.repositoryURL,
            isConfirmed: confirmedDiffKey == key
        )
        do {
            let result = try await repositoryService.loadDiff(request)
            guard loadID == diffLoadID else {
                return
            }
            diff = Self.state(for: result)
            // Only a patch beyond a hard limit offers to open the file elsewhere, so the file
            // system is asked about it then rather than on every selection.
            guard case .beyondHardLimit = result, let path else {
                return
            }
            let fileURL = await Self.existingFileURL(at: path, in: key.repositoryURL)
            guard loadID == diffLoadID else {
                return
            }
            diffFileURL = fileURL
        } catch is CancellationError {
            // The selection moved on. Whichever load replaced this one owns the pane now, so
            // saying the cancelled one failed would report Colofa's own decision as an error.
            return
        } catch {
            guard loadID == diffLoadID else {
                return
            }
            diff = .failed(Self.diffFailure(error))
        }
    }

    private static func state(for result: DiffLoadResult) -> DiffLoadState {
        switch result {
        case .diff(let diff): .loaded(diff)
        case .confirmationRequired(let summary): .confirmationRequired(summary)
        case .beyondHardLimit(let summary): .beyondHardLimit(summary)
        }
    }

    private static func diffFailure(_ error: any Error) -> RepositoryOpenError {
        if let error = error as? RepositoryOpenError {
            return error
        }
        return .commandFailed(
            GitFailureDetails(command: "git diff", output: error.localizedDescription)
        )
    }

    /// Where the selected path is on disk, when it is there at all.
    ///
    /// Asked off the Main Actor, and only once a patch has been refused: the file system can be
    /// slow to answer for a Repository on a network volume, and the Main Actor may not wait on
    /// it. Only the resulting URL is published.
    private static func existingFileURL(at path: String, in repositoryURL: URL) async -> URL? {
        await Task.detached {
            let url = repositoryURL.appending(path: path)
            return FileManager.default.fileExists(atPath: url.normalizedFilePath) ? url : nil
        }.value
    }
}
