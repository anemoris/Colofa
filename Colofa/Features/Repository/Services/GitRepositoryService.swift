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
    private var executableURL: URL?
    private var mutationTail: Task<Void, Never>?

    init(
        candidateURLs: [URL] = GitRepositoryService.defaultCandidateURLs(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.candidateURLs = candidateURLs
        self.environment = environment.merging(["GIT_TERMINAL_PROMPT": "0"]) { _, value in
            value
        }
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

    func validateBranchName(_ request: BranchNameValidationRequest) async throws -> Bool {
        try await GitBranchReader(git: try await resolvedGit()).isValidBranchName(request)
    }

    func loadCheckoutComparison(
        _ request: CheckoutComparisonRequest
    ) async throws -> CheckoutComparison {
        try await GitBranchReader(git: try await resolvedGit()).comparison(request)
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
            operation: GitOperationReader.operation(inGitDirectoryAt: gitDirectoryURL),
            totalCommitCount: try await totalCommitCount(
                head: status.head,
                using: git,
                in: rootURL
            ),
            gitObjectSize: try GitObjectSizeParser.parse(
                try await git.text(["count-objects", "-v"], in: rootURL)
            ),
            configuration: try await GitConfigurationReader.snapshot {
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

    private static func defaultCandidateURLs() -> [URL] {
        let pathCandidates = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map {
                URL(filePath: String($0), directoryHint: .isDirectory)
                    .appending(path: "git")
            }
        let standardCandidates = [
            URL(filePath: "/usr/bin/git"),
            URL(filePath: "/opt/homebrew/bin/git"),
            URL(filePath: "/usr/local/bin/git"),
        ]

        return (pathCandidates + standardCandidates).reduce(into: []) { result, candidate in
            if !result.contains(candidate) {
                result.append(candidate)
            }
        }
    }
}
