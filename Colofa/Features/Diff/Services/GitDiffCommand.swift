////
//  GitDiffCommand.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The Git invocation behind one Diff, kept as a value so the argument list is testable without
/// launching anything.
///
/// Every form disables colour, external Diff tools, and textconv filters: Colofa parses this
/// output, so a user's configured converter would replace the patch with something else.
nonisolated struct GitDiffCommand: Equatable, Sendable {
    let arguments: [String]
    /// `git diff --no-index` reports "the inputs differ" as exit status 1, which for an untracked
    /// path is the expected answer rather than a failure.
    let successfulExitStatuses: Set<Int32>

    static func patch(for source: DiffSource) -> Self {
        command(for: source, output: ["--patch"])
    }

    static func numstat(for source: DiffSource) -> Self {
        command(for: source, output: ["--numstat", "-z"])
    }

    private static func command(for source: DiffSource, output: [String]) -> Self {
        switch source {
        case .index(let paths):
            Self(
                arguments: trackedPrefix + ["diff", "--cached"] + output + trackedOptions
                    + ["--"] + paths,
                successfulExitStatuses: [0]
            )
        case .workingTree(let paths):
            Self(
                arguments: trackedPrefix + ["diff"] + output + trackedOptions + ["--"] + paths,
                successfulExitStatuses: [0]
            )
        case .untracked(let path):
            // An untracked path is in neither HEAD nor the index, so the only comparison Git can
            // make is against nothing. `--no-index` takes filenames rather than pathspecs, and
            // Colofa runs Git from the Repository root, where the path Git reported is valid.
            Self(
                arguments: quotingPrefix + ["diff", "--no-index"] + output + formatOptions
                    + ["--", "/dev/null", path],
                successfulExitStatuses: [0, 1]
            )
        case .commit(let objectID, let parentObjectID, let paths):
            if let parentObjectID {
                // Naming both ends rather than spelling `^` keeps a merge comparing against the
                // first parent it actually has, which is the parent History walked through.
                Self(
                    arguments: trackedPrefix + ["diff"] + output + trackedOptions
                        + [parentObjectID, objectID, "--"] + paths,
                    successfulExitStatuses: [0]
                )
            } else {
                // Nothing to compare against, so Git compares against an empty tree and the
                // Commit reads as everything it introduced. `--root` is what makes it answer at
                // all rather than printing nothing.
                Self(
                    arguments: trackedPrefix + ["show", "--root", "--format="] + output
                        + trackedOptions + [objectID, "--"] + paths,
                    successfulExitStatuses: [0]
                )
            }
        }
    }

    /// `--literal-pathspecs` stops a path that contains a glob character from matching anything
    /// else.
    private static let trackedPrefix = quotingPrefix + ["--literal-pathspecs"]

    /// `core.quotePath=false` keeps a non-ASCII path in the patch header readable rather than
    /// escaped into octal.
    private static let quotingPrefix = ["--no-optional-locks", "-c", "core.quotePath=false"]

    /// Every option a Repository or a user could otherwise decide for Colofa is stated here,
    /// because each of them changes the shape of the output being parsed:
    ///
    /// - `--submodule=short`: `diff.submodule` set to `log` or `diff` replaces the
    ///   `Subproject commit` lines carrying the two Commit IDs with a `Submodule <path>
    ///   <a>..<b>:` summary that is not a patch at all.
    /// - `--src-prefix` / `--dst-prefix`: `diff.noPrefix` drops the `a/` and `b/` prefixes and
    ///   `diff.mnemonicPrefix` replaces them with `i/`, `w/`, `c/`, and `o/`. The header naming
    ///   both paths at once is only separable by those prefixes, so either setting costs a
    ///   binary or mode-only change its paths, and the mnemonic form leaves its letter on every
    ///   path Colofa shows.
    private static let formatOptions = [
        "--no-color", "--no-ext-diff", "--no-textconv", "--submodule=short",
        "--src-prefix=a/", "--dst-prefix=b/",
    ]

    /// Rename detection needs both paths in the pathspec, which is why a renamed Change asks for
    /// its old path as well.
    private static let trackedOptions = ["--find-renames"] + formatOptions
}
