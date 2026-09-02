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
    /// contacts a remote — and it is the only command that can ask for a secret.
    func runNetworkMutation(
        _ command: [String],
        in repositoryURL: URL,
        responder: AuthenticationResponder
    ) async throws {
        if arguments.contains(UITestingArgument.slowFetch) {
            try await Task.sleep(for: UITestingFetch.slowFetchDuration)
        }
        if let refusal = try await authenticationRefusal(answeredBy: responder) {
            throw refusal
        }
        if let failure = UITestingFetch.failure(of: command, arguments: arguments) {
            throw failure
        }
        if let failure = UITestingPush.failure(of: command, arguments: arguments) {
            throw failure
        }
        guard let snapshot = currentSnapshot(at: repositoryURL) else {
            throw RepositoryOpenError.notRepository
        }

        // A Push writes to the remote rather than reading from it, so what it leaves behind is a
        // Branch that now exists there — and, the first time, an upstream to track it by.
        if UITestingPush.isPush(command) {
            accept(command, in: snapshot)
            return
        }

        // A Pull's Fetch downloads whatever its own remote holds rather than inventing a branch
        // nobody pushed: what it brings back is the upstream's real position.
        if UITestingPull.isFetch(command) {
            publish(
                replacing(
                    in: snapshot,
                    upstream: UITestingPull.fetchedUpstream(arguments: arguments)
                )
            )
            return
        }

        let isTagFetch = FetchCommand.isTagFetch(command)
        publish(
            replacing(
                in: snapshot,
                remoteBranches: remoteBranches(after: command, in: snapshot),
                tags: isTagFetch
                    ? adding(UITestingFetch.fetchedTag, to: snapshot.tags)
                    : snapshot.tags
            )
        )
    }

    /// The remote-tracking Branches one command leaves behind.
    ///
    /// A Fetch Tags touches none of them. An ordinary Fetch adds what the remote gained and
    /// leaves the stale one exactly where it is, which is what Git does when nothing asked it to
    /// prune. A Fetch Remotes does both halves: it adds the new Branch and removes the one the
    /// remote no longer has.
    private func remoteBranches(
        after command: [String],
        in snapshot: RepositorySnapshot
    ) -> [String] {
        guard !FetchCommand.isTagFetch(command) else {
            return snapshot.remoteBranches
        }
        let fetched = adding(UITestingFetch.fetchedRemoteBranch, to: snapshot.remoteBranches)
        guard FetchCommand.isRemotesFetch(command) else {
            return fetched
        }
        return fetched.filter { $0 != UITestingFetch.staleRemoteBranch }
    }

    /// Asks the fixture's one question through the same door a real command asks through, and
    /// reports what Git would have written had it gone unanswered.
    ///
    /// - Returns: `nil` when nothing was asked or the question was answered, which is when the
    ///   Fetch goes on.
    private func authenticationRefusal(
        answeredBy responder: AuthenticationResponder
    ) async throws -> RepositoryOpenError? {
        guard !hasAskedAuthentication,
              let prompt = UITestingAuthentication.prompt(arguments: arguments) else {
            return nil
        }
        hasAskedAuthentication = true

        let request = AuthenticationPromptParser.request(for: prompt)
        if request.isAnswerable, case .answer = await responder.respond(request) {
            return nil
        }
        // A refused question leaves the command cancelled rather than failed whenever the user is
        // what refused it, exactly as the real one does.
        try Task.checkCancellation()
        return .commandFailed(
            GitFailureDetails(
                command: "git fetch",
                output: UITestingAuthentication.refusal(of: request.kind),
                exitStatus: 128,
                // Carried rather than left to be recognized in the output, exactly as the real
                // channel carries it: the question is redacted out of what a command reports.
                authenticationFailure: .refusing(request.kind)
            )
        )
    }

    private func adding(_ name: String, to names: [String]) -> [String] {
        names.contains(name) ? names : (names + [name]).sorted()
    }
}
#endif
