////
//  WorkspaceState+Selection.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

extension WorkspaceState {
    /// The Change a selection currently names, or none when the Repository no longer reports it.
    func change(for selection: RepositoryChangeSelection) -> RepositoryChange? {
        guard let repository else {
            return nil
        }
        return changes(in: repository, staged: selection.isStaged)
            .first { $0.path == selection.path }
    }

    /// Keeps the selection pointing at something the Repository still reports.
    ///
    /// A path that only moved between Staged and unstaged — which is what staging it does — keeps
    /// its selection on the other side rather than losing it; a path that is gone loses it.
    ///
    /// Not private: `publishRepository` calls it as each authoritative read lands.
    func updateSelectedChange(for repository: RepositorySnapshot) {
        guard let selectedChange else {
            return
        }
        if changes(in: repository, staged: selectedChange.isStaged)
            .contains(where: { $0.path == selectedChange.path }) {
            return
        }
        let alternate = RepositoryChangeSelection(
            path: selectedChange.path,
            isStaged: !selectedChange.isStaged
        )
        self.selectedChange = changes(in: repository, staged: alternate.isStaged)
            .contains(where: { $0.path == alternate.path }) ? alternate : nil
    }

    private func changes(
        in repository: RepositorySnapshot,
        staged: Bool
    ) -> [RepositoryChange] {
        staged ? repository.stagedChanges : repository.unstagedChanges
    }
}
