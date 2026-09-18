////
//  StashPresentation.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Everything the Stashes pane is showing, kept as one value the Stashes extension owns.
///
/// Grouped rather than spread across the Store because these only ever change together: a
/// Repository read again invalidates the list, the failure, the selected entry, and the paths
/// read for it at once.
nonisolated struct StashPresentation: Equatable, Sendable {
    var state: StashLoadState?

    /// Which Repository the loaded entries belong to. `stash@{0}` in another Repository is a
    /// different Stash that happens to share an address.
    var loadedRepositoryURL: URL?

    /// The selected entry, by the address Git holds it at.
    var selectedStashID: String?

    var loadID = 0
    var detail: StashDetailLoadState?

    /// Which of the selected Stash's paths the Diff pane is reading, by `StashFile.id`.
    var selectedFileID: String?
    var detailLoadID = 0

    var stashes: [Stash]? { state?.stashes }

    /// The same pane holding nothing.
    ///
    /// Both load IDs carry on from where they were rather than starting over, so neither read can
    /// be overtaken by one already in flight: an ID reset to zero is handed out again by the next
    /// read, and the stale answer holding it would land in the pane this emptied.
    func emptied() -> Self {
        Self(loadID: loadID + 1, detailLoadID: detailLoadID + 1)
    }
}
