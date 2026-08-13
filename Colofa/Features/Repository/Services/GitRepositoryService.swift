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
            guard let version = try? await execute(
                candidateURL,
                arguments: ["--version"],
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

        guard case .available(let executableURL) = await availability() else {
            throw RepositoryOpenError.gitUnavailable
        }

        let isBare: String
        do {
            isBare = try await execute(
                executableURL,
                arguments: ["rev-parse", "--is-bare-repository"],
                in: selectedURL
            )
        } catch let error as RepositoryOpenError {
            if !containsGitMetadata(atOrAbove: selectedURL) {
                throw RepositoryOpenError.notRepository
            }
            throw error
        }

        guard isBare != "true" else {
            throw RepositoryOpenError.bareRepository
        }

        let rootPath = try await execute(
            executableURL,
            arguments: ["rev-parse", "--show-toplevel"],
            in: selectedURL
        )
        let gitDirectoryPath = try await execute(
            executableURL,
            arguments: ["rev-parse", "--absolute-git-dir"],
            in: selectedURL
        )
        let rootURL = URL(filePath: rootPath, directoryHint: .isDirectory)
            .standardizedFileURL
        let gitDirectoryURL = URL(filePath: gitDirectoryPath, directoryHint: .isDirectory)
            .standardizedFileURL

        let status = try GitStatusParser.parse(
            try await executeData(
                executableURL,
                arguments: [
                    "--no-optional-locks", "status", "--porcelain=v2", "--branch", "-z", "--renames",
                    "--untracked-files=all",
                ],
                in: rootURL
            )
        )
        let references = try GitReferenceParser.parse(
            try await executeData(
                executableURL,
                arguments: [
                    "for-each-ref", "--format=%(refname)%00%(symref)",
                    "refs/heads", "refs/remotes", "refs/tags",
                ],
                in: rootURL
            )
        )
        let remotes = try GitRemoteParser.parse(
            try await executeDataAllowingNoMatches(
                executableURL,
                arguments: ["config", "--null", "--get-regexp", "^remote\\..*\\.url$"],
                in: rootURL
            )
        )
        let configuration = try await GitConfigurationReader.snapshot {
            try await executeDataAllowingNoMatches(executableURL, arguments: $0, in: rootURL)
        }

        return RepositorySnapshot(
            name: rootURL.lastPathComponent,
            rootURL: rootURL,
            gitDirectoryURL: gitDirectoryURL,
            head: status.head,
            upstream: status.upstream,
            remotes: remotes,
            localBranches: references.localBranches,
            remoteBranches: references.remoteBranches,
            tags: references.tags,
            stagedChanges: status.stagedChanges,
            unstagedChanges: status.unstagedChanges,
            operation: operation(in: gitDirectoryURL),
            totalCommitCount: try await totalCommitCount(
                head: status.head,
                executableURL: executableURL,
                repositoryURL: rootURL
            ),
            gitObjectSize: try await gitObjectSize(
                executableURL: executableURL,
                repositoryURL: rootURL
            ),
            configuration: configuration
        )
    }

    func runMutation(_ arguments: [String], in repositoryURL: URL) async throws {
        let previousMutation = mutationTail
        // Once queued, a mutation must finish so cancellation cannot interrupt an index write.
        let mutation = Task { [self] in
            await previousMutation?.value

            guard case .available(let executableURL) = await availability() else {
                throw RepositoryOpenError.gitUnavailable
            }

            _ = try await execute(executableURL, arguments: arguments, in: repositoryURL)
        }
        mutationTail = Task {
            _ = await mutation.result
        }

        try await mutation.value
    }

    private func totalCommitCount(
        head: RepositoryHead,
        executableURL: URL,
        repositoryURL: URL
    ) async throws -> Int {
        if case .unbornBranch = head {
            return 0
        }
        let output = try await execute(
            executableURL,
            arguments: ["rev-list", "--count", "HEAD"],
            in: repositoryURL
        )
        guard let count = Int(output) else {
            throw GitOutputParsingError()
        }
        return count
    }

    private func gitObjectSize(
        executableURL: URL,
        repositoryURL: URL
    ) async throws -> Int64 {
        let output = try await execute(
            executableURL,
            arguments: ["count-objects", "-v"],
            in: repositoryURL
        )
        return try GitObjectSizeParser.parse(output)
    }

    private func operation(in gitDirectoryURL: URL) -> RepositoryOperation? {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: gitDirectoryURL.appending(path: "rebase-merge").path) {
            return .rebase
        }
        let rebaseApplyURL = gitDirectoryURL.appending(path: "rebase-apply")
        if fileManager.fileExists(atPath: rebaseApplyURL.path) {
            return fileManager.fileExists(
                atPath: rebaseApplyURL.appending(path: "applying").path
            ) ? .am : .rebase
        }
        if fileManager.fileExists(
            atPath: gitDirectoryURL.appending(path: "CHERRY_PICK_HEAD").path
        ) {
            return .cherryPick
        }
        if fileManager.fileExists(atPath: gitDirectoryURL.appending(path: "MERGE_HEAD").path) {
            return .merge
        }
        if fileManager.fileExists(atPath: gitDirectoryURL.appending(path: "REVERT_HEAD").path) {
            return .revert
        }
        return nil
    }

    private func execute(
        _ executableURL: URL,
        arguments: [String],
        in directoryURL: URL
    ) async throws -> String {
        let output = try await executeData(
            executableURL,
            arguments: arguments,
            in: directoryURL,
            outputLimit: 4_000
        )
        return String(decoding: output, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func executeDataAllowingNoMatches(
        _ executableURL: URL,
        arguments: [String],
        in directoryURL: URL
    ) async throws -> Data {
        do {
            return try await executeData(
                executableURL,
                arguments: arguments,
                in: directoryURL
            )
        } catch RepositoryOpenError.commandFailed(let details) where details.exitStatus == 1 {
            return Data()
        }
    }

    private func executeData(
        _ executableURL: URL,
        arguments: [String],
        in directoryURL: URL,
        outputLimit: Int? = nil
    ) async throws -> Data {
        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = directoryURL
        process.environment = environment
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        do {
            try process.run()
        } catch {
            if !FileManager.default.isExecutableFile(atPath: executableURL.normalizedFilePath) {
                self.executableURL = nil
                throw RepositoryOpenError.gitUnavailable
            }
            throw RepositoryOpenError.commandFailed(
                failureDetails(
                    arguments: arguments,
                    repositoryURL: directoryURL,
                    output: error.localizedDescription
                )
            )
        }

        async let standardOutput = Self.readData(
            from: standardOutputPipe.fileHandleForReading,
            limit: outputLimit
        )
        async let standardError = Self.readData(
            from: standardErrorPipe.fileHandleForReading,
            limit: 4_000
        )
        let exitStatus = await Self.waitForTermination(of: process)
        let output: Data
        let errorOutput: Data
        do {
            (output, errorOutput) = try await (standardOutput, standardError)
        } catch {
            throw RepositoryOpenError.commandFailed(
                failureDetails(
                    arguments: arguments,
                    repositoryURL: directoryURL,
                    output: error.localizedDescription,
                    exitStatus: exitStatus
                )
            )
        }

        guard exitStatus == 0 else {
            let diagnosticOutput = [errorOutput, output]
                .map {
                    String(decoding: $0, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw RepositoryOpenError.commandFailed(
                failureDetails(
                    arguments: arguments,
                    repositoryURL: directoryURL,
                    output: diagnosticOutput,
                    exitStatus: exitStatus
                )
            )
        }

        return output
    }

    private func failureDetails(
        arguments: [String],
        repositoryURL: URL,
        output: String,
        exitStatus: Int32? = nil
    ) -> GitFailureDetails {
        let sanitizedOutput = String(
            output
                .replacing("\0", with: "")
                .replacing(repositoryURL.normalizedFilePath, with: "<Repository>")
                .prefix(4_000)
        )
        let command = (["git"] + arguments)
            .map(\.debugDescription)
            .joined(separator: " ")
            .replacing(repositoryURL.normalizedFilePath, with: "<Repository>")

        return GitFailureDetails(
            command: command,
            output: sanitizedOutput,
            exitStatus: exitStatus
        )
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

    private nonisolated static func readData(
        from handle: FileHandle,
        limit: Int?
    ) async throws -> Data {
        var output = Data()
        for try await byte in handle.bytes {
            if output.count < (limit ?? .max) {
                output.append(byte)
            }
        }
        return output
    }

    private nonisolated static func waitForTermination(of process: Process) async -> Int32 {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { process in
                    continuation.resume(returning: process.terminationStatus)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
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
