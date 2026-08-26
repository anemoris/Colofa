////
//  UITestingRepositoryService.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

actor UITestingRepositoryService {
    /// Not private: the branch extension in UITestingRepositoryService+Branches.swift reads the
    /// same launch arguments, and Swift keeps `private` within one file.
    let arguments: [String]

    /// Whether this fixture's Git has already had its one question answered.
    ///
    /// Not private: the Fetch extension in UITestingRepositoryService+Fetch.swift is what asks,
    /// and Swift keeps `private` within one file. A real credential helper is consulted once and
    /// then holds the answer, so a Fetch of several remotes must not ask again per remote.
    var hasAskedAuthentication = false

    private var snapshot: RepositorySnapshot?

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func loadRepository(at url: URL) throws -> RepositorySnapshot {
        if arguments.contains(UITestingArgument.bareRepository) {
            throw RepositoryOpenError.bareRepository
        }
        if let snapshot, snapshot.rootURL == url {
            return snapshot
        }

        let snapshot = UITestingRepositorySnapshots.initial(at: url, arguments: arguments)
        self.snapshot = snapshot
        return snapshot
    }

    /// The Repository the stub currently reports, for an extension that mutates it.
    ///
    /// Not private: the Fetch extension in UITestingRepositoryService+Fetch.swift reads and
    /// replaces it, and Swift keeps `private` within one file.
    func currentSnapshot(at url: URL) -> RepositorySnapshot? {
        guard let snapshot, snapshot.rootURL == url else {
            return nil
        }
        return snapshot
    }

    func publish(_ snapshot: RepositorySnapshot) {
        self.snapshot = snapshot
    }

    func loadDiff(_ request: DiffLoadRequest) async throws -> DiffLoadResult {
        try await UITestingDiffs.result(for: request)
    }

    func loadHistory(_ request: HistoryPageRequest) -> HistoryPage {
        UITestingHistory.page(for: request)
    }

    func loadCommitDetail(_ request: HistoryCommitDetailRequest) -> HistoryCommitDetail {
        UITestingHistory.detail(for: request)
    }

    func validateBranchName(_ request: BranchNameValidationRequest) -> Bool {
        UITestingBranches.isValidName(request.name)
    }

    func runMutation(
        _ command: [String],
        standardInput: String? = nil,
        in repositoryURL: URL
    ) throws {
        try throwRequestedMutationFailure()
        try throwRequestedCheckoutRefusal(of: command)
        guard let snapshot, snapshot.rootURL == repositoryURL else {
            throw RepositoryOpenError.notRepository
        }

        if UITestingPull.isFastForward(command) {
            try fastForward(in: snapshot)
            return
        }

        if command.first == "config" {
            self.snapshot = replacing(
                in: snapshot,
                configuration: configurationMutation(command, in: snapshot.configuration)
            )
            return
        }

        if command.first == "commit" {
            let isAmending = command.contains("--amend")
            self.snapshot = replacing(
                in: snapshot,
                head: committedHead(in: snapshot),
                staged: [],
                headCommit: committed(standardInput ?? "", in: snapshot, isAmending: isAmending),
                upstream: committedUpstream(in: snapshot, isAmending: isAmending),
                totalCommitCount: snapshot.totalCommitCount + (isAmending ? 0 : 1)
            )
            return
        }

        if let branched = branchMutation(command, in: snapshot) {
            self.snapshot = branched
            return
        }

        updateChanges(for: command, in: snapshot)
    }

    private func throwRequestedMutationFailure() throws {
        if arguments.contains(UITestingArgument.commitHookFailure) {
            throw RepositoryOpenError.commandFailed(
                GitFailureDetails(command: "git commit", output: "pre-commit rejected the Commit")
            )
        }
        if arguments.contains(UITestingArgument.commitSigningFailure) {
            throw RepositoryOpenError.commandFailed(
                GitFailureDetails(command: "git commit", output: "Commit signing failed")
            )
        }
        if arguments.contains(UITestingArgument.stageFailure) {
            throw RepositoryOpenError.commandFailed(
                GitFailureDetails(command: "git", output: "UI test mutation failed")
            )
        }
    }

    private func updateChanges(for command: [String], in snapshot: RepositorySnapshot) {
        let paths = command.drop { $0 != "--" }.dropFirst()
        var staged = snapshot.stagedChanges
        var unstaged = snapshot.unstagedChanges
        let action = command.drop { $0 == "--literal-pathspecs" }.first
        if action == "add" {
            let changes = unstaged.filter { change in
                !change.isConflict && change.gitPathspecs.contains { paths.contains($0) }
            }
            unstaged.removeAll { changes.contains($0) }
            for change in changes where !staged.contains(change) {
                staged.append(change)
            }
        } else if action == "restore" || action == "rm" {
            let changes = staged.filter { change in
                change.gitPathspecs.contains { paths.contains($0) }
            }
            staged.removeAll { changes.contains($0) }
            for change in changes where !unstaged.contains(change) {
                unstaged.append(change)
            }
        }

        self.snapshot = replacing(
            in: snapshot,
            staged: staged.sorted { $0.path < $1.path },
            unstaged: unstaged.sorted(by: changeOrder)
        )
    }

    /// The Commit the stub now reports at HEAD. A fresh Commit is unpublished; an Amend keeps
    /// whatever the rewritten Commit was, which is what makes the warning reappear.
    private func committed(
        _ message: String,
        in snapshot: RepositorySnapshot,
        isAmending: Bool
    ) -> RepositoryHeadCommit {
        let lines = message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        return RepositoryHeadCommit(
            objectID: "ui-\(isAmending ? "amend" : "commit")-\(snapshot.totalCommitCount)",
            summary: String(lines.first ?? ""),
            body: lines.count > 1
                ? String(lines[1]).trimmingCharacters(in: .newlines)
                : "",
            isPublished: isAmending && snapshot.headCommit?.isPublished == true
        )
    }

    private func committedHead(in snapshot: RepositorySnapshot) -> RepositoryHead {
        if case .unbornBranch(let branch) = snapshot.head {
            .branch(branch)
        } else {
            snapshot.head
        }
    }

    private func committedUpstream(
        in snapshot: RepositorySnapshot,
        isAmending: Bool
    ) -> RepositoryUpstream? {
        guard let upstream = snapshot.upstream else {
            return nil
        }
        if isAmending && snapshot.headCommit?.isPublished == true {
            return RepositoryUpstream(
                name: upstream.name,
                ahead: upstream.ahead + 1,
                behind: upstream.behind + 1
            )
        }
        return RepositoryUpstream(
            name: upstream.name,
            ahead: upstream.ahead + (isAmending ? 0 : 1),
            behind: upstream.behind
        )
    }

    private func configurationMutation(
        _ command: [String],
        in configuration: GitConfigurationSnapshot
    ) -> GitConfigurationSnapshot {
        let scope: GitConfigurationEditScope = command.contains("--global") ? .global : .repository
        guard let key = command.compactMap(GitConfigurationKey.init(rawValue:)).first else {
            return configuration
        }

        // Both write forms replace whatever the scope held, so the scope is cleared first and a
        // value appended only when the command carries one.
        var entries = configuration.entries.filter {
            !($0.key == key && $0.scope == scope.gitScope)
        }
        let isUnset = command.contains { $0.hasPrefix("--unset") }
        if !isUnset,
           let keyIndex = command.firstIndex(of: key.rawValue),
           command.index(after: keyIndex) < command.endIndex {
            let value = command[command.index(after: keyIndex)]
            let origin = scope == .global
                ? GitConfigurationOrigin(rawValue: "file:/tmp/colofa-ui-global.gitconfig")
                : GitConfigurationOrigin(rawValue: "file:.git/config")
            entries.append(
                GitConfigurationEntry(
                    key: key,
                    value: value,
                    scope: scope.gitScope,
                    origin: origin
                )
            )
        }
        entries.sort {
            ($0.scope.precedenceRank ?? Int.max) < ($1.scope.precedenceRank ?? Int.max)
        }
        return GitConfigurationSnapshot(entries: entries)
    }

    /// Copies `snapshot`, overriding only the fields a mutation touched.
    ///
    /// Not private: the branch extension in UITestingRepositoryService+Branches.swift builds its
    /// own snapshots through it, and Swift keeps `private` within one file.
    ///
    /// `RepositorySnapshot` has no `with`-style API, so every stub mutation would otherwise
    /// restate all of its fields and silently drop whichever one a future property forgot.
    func replacing(
        in snapshot: RepositorySnapshot,
        head: RepositoryHead? = nil,
        localBranches: [String]? = nil,
        remoteBranches: [String]? = nil,
        tags: [String]? = nil,
        staged: [RepositoryChange]? = nil,
        unstaged: [RepositoryChange]? = nil,
        headCommit: RepositoryHeadCommit? = nil,
        upstream: RepositoryUpstream? = nil,
        totalCommitCount: Int? = nil,
        configuration: GitConfigurationSnapshot? = nil
    ) -> RepositorySnapshot {
        RepositorySnapshot(
            name: snapshot.name,
            rootURL: snapshot.rootURL,
            gitDirectoryURL: snapshot.gitDirectoryURL,
            head: head ?? snapshot.head,
            headCommit: headCommit ?? snapshot.headCommit,
            upstream: upstream ?? snapshot.upstream,
            remotes: snapshot.remotes,
            localBranches: localBranches ?? snapshot.localBranches,
            remoteBranches: remoteBranches ?? snapshot.remoteBranches,
            tags: tags ?? snapshot.tags,
            stagedChanges: staged ?? snapshot.stagedChanges,
            unstagedChanges: unstaged ?? snapshot.unstagedChanges,
            operation: snapshot.operation,
            totalCommitCount: totalCommitCount ?? snapshot.totalCommitCount,
            gitObjectSize: snapshot.gitObjectSize,
            configuration: configuration ?? snapshot.configuration
        )
    }

    private func changeOrder(_ lhs: RepositoryChange, _ rhs: RepositoryChange) -> Bool {
        if lhs.isConflict != rhs.isConflict {
            return lhs.isConflict
        }
        return lhs.path < rhs.path
    }
}
#endif
