////
//  GitBranchReader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The two read-only questions branch work asks Git: whether a name is one Git would accept, and
/// which paths a Ref would rewrite.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` reads these from an actor.
nonisolated struct GitBranchReader {
    let git: GitProcess

    /// The status `check-ref-format` exits with when it has read the name and refused it.
    ///
    /// Git reports an unacceptable name by dying, which is an answer rather than a failure. Every
    /// other way the command can end — Git missing, unlaunchable, or its output unreadable — is a
    /// failure about Git, and saying "that name is invalid" about one would be a lie.
    private static let refusedExitStatus: Int32 = 128

    /// Whether Git itself accepts `name` as a branch name.
    ///
    /// `check-ref-format --branch` applies the same rule `git branch` does, which is stricter
    /// than the refname rule alone: it also refuses `HEAD` and anything shaped like an option.
    /// Colofa asks it rather than reproducing Git's rules, so it accepts exactly what Git accepts.
    ///
    /// A name Git rewrites is refused too. `--branch` resolves shorthands such as `@{-1}`, and
    /// creating a branch under a name the user did not type is not what the dialog showed.
    ///
    /// - Throws: When Git could not be asked at all, so the dialog reports that instead of
    ///   blaming the name.
    func isValidBranchName(_ request: BranchNameValidationRequest) async throws -> Bool {
        // A leading hyphen never reaches Git's option parser. `git branch` refuses such a name
        // anyway, so this is Git's own answer given without handing Git a user string to parse.
        guard !request.name.isEmpty,
              !request.name.hasPrefix(BranchNameValidation.optionPrefix) else {
            return false
        }
        do {
            let normalized = try await git.text(
                ["check-ref-format", "--branch", request.name],
                in: request.repositoryURL
            )
            return normalized == request.name
        } catch RepositoryOpenError.commandFailed(let details)
            where details.exitStatus == Self.refusedExitStatus {
            return false
        }
    }

    /// Which paths the target Ref changes relative to HEAD.
    func comparison(_ request: CheckoutComparisonRequest) async throws -> CheckoutComparison {
        guard request.hasHeadCommit else {
            return try GitNameStatusParser.parseTreePaths(
                try await git.data(
                    ["ls-tree", "-r", "--name-only", "-z", request.revision],
                    in: request.repositoryURL
                )
            )
        }
        return try GitNameStatusParser.parse(
            try await git.data(
                [
                    "diff", "--name-status", "-z", "--no-renames",
                    "HEAD", request.revision, "--",
                ],
                in: request.repositoryURL
            )
        )
    }
}
