////
//  WorkspaceState+Mutations.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Running one mutating Git command and reading the Repository back afterwards.
///
/// Every command that changes the Repository comes through here, which is what makes the two
/// promises around one true for all of them: only one runs at a time, and none of them is over
/// until an authoritative read has said what it actually did.
extension WorkspaceState {
    /// - Parameter failureTitle: What the shared alert is titled when the command fails.
    /// - Returns: Whether the command ran and succeeded, so a caller can keep composer state
    ///   after a failure the user still has to act on.
    @discardableResult
    func performMutation(
        _ arguments: [String],
        standardInput: String? = nil,
        rewritesHead: Bool = false,
        failureTitle: LocalizedStringResource = .gitOperationFailed
    ) async -> Bool {
        let outcome = await runMutation(
            arguments,
            standardInput: standardInput,
            rewritesHead: rewritesHead
        )
        guard case .failed(let error) = outcome else {
            return outcome == .succeeded
        }
        presentMutationError(error, title: failureTitle)
        return false
    }

    /// Runs one mutating command and reports its failure instead of presenting it, so a caller
    /// that can explain a particular refusal better than the shared alert does gets the chance.
    ///
    /// - Parameter rewritesHead: Whether this command moves HEAD on purpose, which only an Amend
    ///   does. Every reload that lands while it runs — the authoritative one, or an ordinary
    ///   refresh a scene activation started alongside it — then reports the rewrite Colofa asked
    ///   for, and must not mistake it for somebody else rewriting History.
    func runMutation(
        _ arguments: [String],
        standardInput: String? = nil,
        rewritesHead: Bool = false
    ) async -> MutationOutcome {
        // Keep the mutation and authoritative reload alive if the initiating view task is cancelled.
        await Task {
            guard let repository, canMutateRepository else {
                return MutationOutcome.unavailable
            }
            isPerformingMutation = true
            isRewritingHead = rewritesHead
            defer {
                isPerformingMutation = false
                isRewritingHead = false
            }

            var commandError: RepositoryOpenError?
            do {
                try await repositoryService.runMutation(
                    arguments,
                    standardInput,
                    repository.rootURL
                )
            } catch let error as RepositoryOpenError {
                commandError = error
            } catch {
                commandError = .commandFailed(
                    GitFailureDetails(command: "git", output: error.localizedDescription)
                )
            }

            await refresh()
            if let commandError {
                // The command rewrote nothing Colofa asked for, so a HEAD that moved anyway — a
                // Hook that rewrote it before refusing — still invalidates an open Amend draft.
                reconcileAmendDraft()
                return .failed(commandError)
            }
            return .succeeded
        }.value
    }
}
