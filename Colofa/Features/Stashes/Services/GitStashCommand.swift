////
//  GitStashCommand.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The Git invocations behind reading Stashes, kept as values so the argument lists are testable
/// without launching anything.
///
/// The command that *creates* one lives on `StashCreationDraft`, because there the options are
/// the command.
nonisolated enum GitStashCommand {

    /// Every entry Git holds, newest first, as a flat stream of NUL-terminated fields.
    ///
    /// `git stash list` is `git log` over the Stash reflog, so it takes the same options — and
    /// needs the same ones stated: colour, signature verification, and notes each append output
    /// that is not part of the record being parsed.
    ///
    /// `-z` ends every record with NUL, the same byte that separates its fields, so records are
    /// told apart by counting fields rather than by a separator. NUL is the one byte nothing in a
    /// record can hold; a printable-looking separator such as `0x1e` survives into the stored
    /// description when a message carries it, and would split that entry in two.
    static let list = [
        "--no-optional-locks", "stash", "list", "-z", "--no-color", "--no-show-signature",
        "--no-notes", "--format=\(recordFormat)",
    ]

    /// `%gd` is how Git addresses the entry and `%gs` is the description it stored for it; the
    /// three parents in `%P` are the objects the entry was built from. The time is a UNIX
    /// timestamp, so no Repository setting, locale, or parser stands between Git and the value.
    static let recordFields = ["%gd", "%H", "%h", "%P", "%an", "%ae", "%at", "%gs"]

    static let recordFormat = recordFields.joined(separator: "%x00")
}
