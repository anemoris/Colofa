////
//  UITestingRepositoryService+Fetch.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

#if DEBUG
import Foundation

/// What the stubbed backend does with the commands Fetch runs, so UI tests can assert the
/// Repository state each one leaves behind — including the one the user stopped.
extension UITestingRepositoryService {
    func skippedRemotes() -> Set<String> {
        UITestingFetch.skippedRemotes(arguments: arguments)
    }

    func tagConflicts(_ request: TagConflictRequest) -> TagFetchConflict {
        UITestingFetch.tagConflicts(arguments: arguments)
    }

    /// Unlike `runMutation`, this one is cancellable, because the command it stands in for
    /// contacts a remote.
    func runNetworkMutation(_ command: [String], in repositoryURL: URL) async throws {
        if arguments.contains(UITestingArgument.slowFetch) {
            try await Task.sleep(for: UITestingFetch.slowFetchDuration)
        }
        if let failure = UITestingFetch.failure(of: command, arguments: arguments) {
            throw failure
        }
        guard let snapshot = currentSnapshot(at: repositoryURL) else {
            throw RepositoryOpenError.notRepository
        }

        let isTagFetch = FetchCommand.isTagFetch(command)
        publish(
            replacing(
                in: snapshot,
                remoteBranches: isTagFetch
                    ? snapshot.remoteBranches
                    : adding(UITestingFetch.fetchedRemoteBranch, to: snapshot.remoteBranches),
                tags: isTagFetch
                    ? adding(UITestingFetch.fetchedTag, to: snapshot.tags)
                    : snapshot.tags
            )
        )
    }

    private func adding(_ name: String, to names: [String]) -> [String] {
        names.contains(name) ? names : (names + [name]).sorted()
    }
}
#endif
