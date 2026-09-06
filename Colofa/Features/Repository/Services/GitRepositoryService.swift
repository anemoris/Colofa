////
//  GitRepositoryService.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

actor GitRepositoryService {
    private let candidateURLs: [URL]
    private let environment: [String: String]

    /// The executable Git and OpenSSH run to ask for a secret: the AskPass tool bundled beside
    /// the app, which relays one question and exits.
    ///
    /// Injectable so a test can hand a controlled program the same channel a real one gets.
    private let askPassHelperURL: URL?

    private var executableURL: URL?
    private var mutationTail: Task<Void, Never>?

    /// `candidateURLs` defaults to the search path `environment` resolves to, so the two are one
    /// answer rather than two lists that can disagree — including for an injected `environment`,
    /// which a default argument could not have read.
    init(
        candidateURLs: [URL]? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        askPassHelperURL: URL? = GitRepositoryService.bundledAskPassHelperURL()
    ) {
        // Keeps Git from waiting on a terminal Colofa does not have. An AskPass program is
        // consulted before this applies, so a question Colofa can ask is still asked.
        //
        // The search path is resolved here rather than at each command, because every program Git
        // starts inherits this environment: its own helpers, OpenSSH, and whatever those two go on
        // to run.
        let environment = GitSearchPath.resolving(environment)
            .merging(["GIT_TERMINAL_PROMPT": "0"]) { _, value in
                value
            }

        self.environment = environment
        self.candidateURLs = candidateURLs ?? Self.candidateURLs(searchedBy: environment)
        self.askPassHelperURL = askPassHelperURL
    }

    func availability() async -> GitAvailability {
        if let executableURL {
            if FileManager.default.isExecutableFile(atPath: executableURL.normalizedFilePath) {
                return .available(executableURL)
            }
            self.executableURL = nil
        }

        for candidateURL in candidateURLs where FileManager.default.isExecutableFile(
            atPath: candidateURL.normalizedFilePath
        ) {
            let candidate = GitProcess(executableURL: candidateURL, environment: environment)
            guard let version = try? await candidate.text(
                ["--version"],
                in: .temporaryDirectory
            ), version.hasPrefix("git version ") else {
                continue
            }

            executableURL = candidateURL
            return .available(candidateURL)
        }

        return .unavailable
    }

    func loadRepository(at selectedURL: URL) async throws -> RepositorySnapshot {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: selectedURL.normalizedFilePath,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            throw RepositoryOpenError.locationUnavailable
        }

        let git = try await resolvedGit()
        let isBare: String
        do {
            isBare = try await git.text(["rev-parse", "--is-bare-repository"], in: selectedURL)
        } catch let error as RepositoryOpenError {
            if !containsGitMetadata(atOrAbove: selectedURL) {
                throw RepositoryOpenError.notRepository
            }
            throw error
        }
        guard isBare != "true" else {
            throw RepositoryOpenError.bareRepository
        }

        return try await snapshot(
            rootURL: try await directoryURL(
                reportedBy: ["rev-parse", "--show-toplevel"],
                using: git,
                in: selectedURL
            ),
            gitDirectoryURL: try await directoryURL(
                reportedBy: ["rev-parse", "--absolute-git-dir"],
                using: git,
                in: selectedURL
            ),
            using: git
        )
    }

    func loadDiff(_ request: DiffLoadRequest) async throws -> DiffLoadResult {
        try await GitDiffLoader(git: try await resolvedGit()).load(request)
    }

    func loadHistory(_ request: HistoryPageRequest) async throws -> HistoryPage {
        try await GitHistoryReader(git: try await resolvedGit()).page(request)
    }

    func loadCommitDetail(
        _ request: HistoryCommitDetailRequest
    ) async throws -> HistoryCommitDetail {
        try await GitHistoryReader(git: try await resolvedGit()).commitDetail(request)
    }

    func runMutation(
        _ arguments: [String],
        standardInput: String? = nil,
        in repositoryURL: URL
    ) async throws {
        let previousMutation = mutationTail
        // Once queued, a mutation must finish so cancellation cannot interrupt an index write.
        let mutation = Task { [self] in
            await previousMutation?.value
            _ = try await resolvedGit().text(
                arguments,
                in: repositoryURL,
                standardInput: standardInput
            )
        }
        mutationTail = Task {
            _ = await mutation.result
        }

        try await mutation.value
    }

    private func snapshot(
        rootURL: URL,
        gitDirectoryURL: URL,
        using git: GitProcess
    ) async throws -> RepositorySnapshot {
        let status = try await status(using: git, in: rootURL)
        let references = try await references(using: git, in: rootURL)
        // Read once and reused: what an unfinished Merge is bringing in is only asked for when
        // there is one, so an ordinary Repository pays nothing for the question.
        let operation = GitOperationReader.operation(inGitDirectoryAt: gitDirectoryURL)

        return RepositorySnapshot(
            name: rootURL.lastPathComponent,
            rootURL: rootURL,
            gitDirectoryURL: gitDirectoryURL,
            head: status.head,
            headCommit: try await GitHeadCommitReader.headCommit(
                head: status.head,
                hasRemoteBranches: !references.remoteBranches.isEmpty,
                using: git,
                in: rootURL
            ),
            upstream: status.upstream,
            remotes: try GitRemoteParser.parse(
                try await git.dataAllowingNoMatches(
                    ["config", "--null", "--get-regexp", "^remote\\..*\\.url$"],
                    in: rootURL
                )
            ),
            localBranches: references.localBranches,
            remoteBranches: references.remoteBranches,
            tags: references.tags,
            stagedChanges: status.stagedChanges,
            unstagedChanges: status.unstagedChanges,
            operation: operation,
            mergeHead: operation == .merge
                ? try await GitMergeReader(git: git).mergeHead(inRepositoryAt: rootURL)
                : nil,
            totalCommitCount: try await totalCommitCount(
                head: status.head,
                using: git,
                in: rootURL
            ),
            gitObjectSize: try GitObjectSizeParser.parse(
                try await git.text(["count-objects", "-v"], in: rootURL)
            ),
            configuration: try await GitConfigurationReader.snapshot(
                globalWriteTarget: GitGlobalConfigurationFile.writeTarget(environment: environment)
            ) {
                try await git.dataAllowingNoMatches($0, in: rootURL)
            }
        )
    }

    private func status(using git: GitProcess, in rootURL: URL) async throws -> RepositoryStatus {
        try GitStatusParser.parse(
            try await git.data(
                [
                    "--no-optional-locks", "status", "--porcelain=v2", "--branch", "-z", "--renames",
                    "--untracked-files=all",
                ],
                in: rootURL
            )
        )
    }

    private func references(
        using git: GitProcess,
        in rootURL: URL
    ) async throws -> RepositoryReferences {
        try GitReferenceParser.parse(
            try await git.data(
                [
                    "for-each-ref", "--format=%(refname)%00%(symref)",
                    "refs/heads", "refs/remotes", "refs/tags",
                ],
                in: rootURL
            )
        )
    }

    private func resolvedGit() async throws -> GitProcess {
        guard case .available(let executableURL) = await availability() else {
            throw RepositoryOpenError.gitUnavailable
        }
        return GitProcess(executableURL: executableURL, environment: environment)
    }

    private func directoryURL(
        reportedBy arguments: [String],
        using git: GitProcess,
        in selectedURL: URL
    ) async throws -> URL {
        URL(
            filePath: try await git.text(arguments, in: selectedURL),
            directoryHint: .isDirectory
        )
        .standardizedFileURL
    }

    private func totalCommitCount(
        head: RepositoryHead,
        using git: GitProcess,
        in repositoryURL: URL
    ) async throws -> Int {
        if case .unbornBranch = head {
            return 0
        }
        guard let count = Int(
            try await git.text(["rev-list", "--count", "HEAD"], in: repositoryURL)
        ) else {
            throw GitOutputParsingError()
        }
        return count
    }

    private func containsGitMetadata(atOrAbove selectedURL: URL) -> Bool {
        var directoryURL = selectedURL.standardizedFileURL

        while true {
            if FileManager.default.fileExists(
                atPath: directoryURL.appending(path: ".git").normalizedFilePath
            ) {
                return true
            }

            if directoryURL.normalizedFilePath == "/" {
                return false
            }
            directoryURL.deleteLastPathComponent()
        }
    }

    /// The AskPass tool inside the running app, or `nil` when there is none to find — which is
    /// how a host that is not the app, such as a test runner, ends up without a channel.
    static func bundledAskPassHelperURL() -> URL? {
        Bundle.main.url(forAuxiliaryExecutable: askPassHelperName)
    }

    /// The bundled AskPass tool's product name, which is also what the app copies into its own
    /// executable directory.
    static let askPassHelperName = "ColofaAskPass"

    /// Where to look for Git itself: a `git` in each directory of the very search path Git is
    /// then given for its own helper programs — one answer to "where are the tools", rather than
    /// two lists that can disagree.
    private static func candidateURLs(searchedBy environment: [String: String]) -> [URL] {
        GitSearchPath.directories(in: environment).map {
            URL(filePath: $0, directoryHint: .isDirectory)
                .appending(path: "git")
        }
    }
}

/// The commands that contact a remote, and the read-only questions they need answered first.
///
/// Grouped apart from the rest because they behave differently: they can be stopped, they are the
/// only commands whose duration Colofa cannot bound, and what they are allowed to contact comes
/// out of Git's configuration rather than out of a snapshot.
extension GitRepositoryService {
    func loadSkippedRemotes(in repositoryURL: URL) async throws -> Set<String> {
        try await GitRemoteReader(git: try await resolvedGit())
            .skippedRemotes(in: repositoryURL)
    }

    func loadTagConflicts(_ request: TagConflictRequest) async throws -> TagFetchConflict {
        try await GitRemoteReader(git: try await resolvedGit()).tagConflicts(request)
    }

    func loadPublishRemote(_ request: PushTargetRequest) async throws -> String? {
        try await GitPushReader(git: try await resolvedGit()).remote(request)
    }

    func loadPushTarget(_ request: PushTargetRequest) async throws -> PushTarget? {
        try await GitPushReader(git: try await resolvedGit()).target(request)
    }

    func loadPushDestination(_ request: PushDestinationRequest) async throws -> PushDestination {
        try await GitPushReader(git: try await resolvedGit()).destination(request)
    }

    /// Runs one command that contacts a remote.
    ///
    /// Unlike `runMutation`, this one can be stopped. A network command has no duration Colofa
    /// can promise, and ending one leaves the Repository's refs exactly as far along as Git had
    /// already written them — which is a state a reload reports truthfully. It still queues
    /// behind whatever mutation is already running, so stopping it can never interrupt an index
    /// write somebody else started.
    /// - Parameter responder: Who answers the questions Git and OpenSSH ask while it runs. They
    ///   only ask once the credential helpers, Keychain integration, and SSH agent the user
    ///   configured have answered nothing, and the channel that carries the question exists only
    ///   for the length of this command.
    func runNetworkMutation(
        _ arguments: [String],
        in repositoryURL: URL,
        responder: AuthenticationResponder
    ) async throws {
        let previousMutation = mutationTail
        let mutation = Task { [self] in
            await previousMutation?.value
            // Cancelled while queued behind another command: nothing should be launched at all.
            try Task.checkCancellation()
            let git = try await resolvedGit()
            let channel = AskPassChannel.opened(
                pointingAt: askPassHelperURL,
                answeredBy: responder
            )
            // However this command ends — finished, failed, or cancelled — the channel and the
            // socket behind it go with it.
            defer { channel.stop() }
            do {
                _ = try await channel.authenticating(git).text(arguments, in: repositoryURL)
            } catch {
                throw channel.explaining(error)
            }
        }
        mutationTail = Task {
            _ = await mutation.result
        }

        // The queued task is unstructured, so cancellation has to be forwarded to it by hand.
        try await withTaskCancellationHandler {
            try await mutation.value
        } onCancel: {
            mutation.cancel()
        }
    }
}

/// The read-only questions branch work asks Git.
///
/// Grouped apart from the Repository read because none of them is published state: each is asked
/// when one branch command is about to run, and answers what that command would do rather than
/// what the Repository is.
extension GitRepositoryService {
    func validateBranchName(_ request: BranchNameValidationRequest) async throws -> Bool {
        try await GitBranchReader(git: try await resolvedGit()).isValidBranchName(request)
    }

    func loadCheckoutComparison(
        _ request: CheckoutComparisonRequest
    ) async throws -> CheckoutComparison {
        try await GitBranchReader(git: try await resolvedGit()).comparison(request)
    }

    func loadBranchDeletionSurvey(
        _ request: BranchDeletionRequest
    ) async throws -> BranchDeletionSurvey? {
        try await GitBranchReader(git: try await resolvedGit()).deletionSurvey(request)
    }
}
