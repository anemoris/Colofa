////
//  MergeCommand.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The commands that end an unfinished Merge, and the one that resolves a path inside it, kept in
/// one place so what Colofa asks Git for can be read — and tested — without reading the Store.
///
/// The command each strategy runs to *start* a Merge lives on `MergeStrategy`, because there the
/// policy is the command.
nonisolated enum MergeCommand {

    /// Completing the merge, which records the merge Commit from the message Git already prepared.
    ///
    /// Deliberately `git commit` rather than `git merge --continue`. The two record the same
    /// Commit from the same `MERGE_MSG`, but `--continue` launches the user's configured editor,
    /// and a button called Continue must not open one — nor hang waiting for a terminal Colofa
    /// does not have. `--no-edit` takes the prepared message as it stands, and `--cleanup=strip`
    /// removes the commented conflict list Git wrote into it, which is exactly what the editor
    /// path would have stripped. No Hook is skipped: there is no `--no-verify` here.
    static let completing = ["commit", "--no-edit", "--cleanup=strip"]

    /// Git's own merge rollback, which restores the Branch, the index, and the working tree to
    /// what they were before the Merge started.
    static let abort = ["merge", "--abort"]

    /// Recording whatever the file holds right now, which is what stops Git reporting the path as
    /// unmerged. It merges nothing and checks nothing.
    static func markingResolved(_ pathspecs: [String]) -> [String] {
        ["--literal-pathspecs", "add", "--"] + pathspecs
    }
}
