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
        let repositoryURL: URL
        let selection: RepositoryChangeSelection
        let kind: RepositoryChangeKind
        let generation: Int
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
        guard let repository,
              let selection = selectedChange,
              let change = change(for: selection) else {
            return nil
        }
        return DiffIdentity(
            repositoryURL: repository.rootURL,
            selection: selection,
            kind: change.kind,
            generation: repositoryGeneration
        )
    }

    /// Reads the patch for the current selection, or clears the pane when there is nothing to
    /// read. A selection that disappeared leaves no Diff behind.
    func loadDiff() async {
        guard let repository,
              let selection = selectedChange,
              let change = change(for: selection) else {
            clearDiff()
            return
        }
        guard !change.isConflict else {
            // An unmerged path has no two-sided comparison to show until it is resolved.
            clearDiff(showing: .conflicted)
            return
        }

        let key = DiffKey(
            repositoryURL: repository.rootURL,
            source: DiffSource(change: change, isStaged: selection.isStaged)
        )
        if key != loadedDiffKey {
            confirmedDiffKey = nil
        }
        // A path whose Change became a different one — a modification that became a deletion —
        // keeps its source but no longer describes the same comparison, so the previous patch is
        // cleared rather than left up while the new one is read. Re-reading the same Change after
        // an ordinary reload is what must not flicker.
        let describesTheSameChange = key == loadedDiffKey && change.kind == loadedDiffKind
        loadedDiffKind = change.kind
        await load(key, path: selection.path, showsLoading: !describesTheSameChange)
    }

    /// Renders a patch above an automatic limit after the user asked for it. The hard limits
    /// still apply: this raises the bound reading stops at rather than removing one.
    func loadDiffAnyway() async {
        guard case .confirmationRequired = diff,
              let repository,
              let selection = selectedChange,
              let change = change(for: selection),
              !change.isConflict else {
            return
        }
        // What the offer is answered with is read for what the workspace is on now, not for what
        // it was on when the offer was made. The key is rebuilt from the current Repository and
        // selection and has to be the very one the offer was made for: a selection that moved
        // while the offer stood — before its own read has run — takes the offer with it, rather
        // than confirming the previous comparison against the new path.
        let key = DiffKey(
            repositoryURL: repository.rootURL,
            source: DiffSource(change: change, isStaged: selection.isStaged)
        )
        guard key == loadedDiffKey else {
            return
        }
        confirmedDiffKey = key
        await load(key, path: selection.path, showsLoading: true)
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
        path: String,
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
            guard case .beyondHardLimit = result else {
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
