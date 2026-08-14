////
//  GitTestRepository.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// An isolated real-Git fixture that never reads the developer's configuration.
final class GitTestRepository {
    let rootURL: URL

    let environment: [String: String]
    private let gitURL = URL(filePath: "/usr/bin/git")

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appending(path: "ColofaTests-\(UUID().uuidString)", directoryHint: .isDirectory)

        let homeURL = rootURL.appending(path: "home", directoryHint: .isDirectory)
        let systemConfigurationURL = rootURL.appending(path: "system.gitconfig")
        let configurationURL = rootURL.appending(path: "global.gitconfig")
        let xdgConfigurationURL = rootURL.appending(path: "xdg", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: xdgConfigurationURL, withIntermediateDirectories: true)

        var isolatedEnvironment = ProcessInfo.processInfo.environment
        for key in isolatedEnvironment.keys where key.hasPrefix("GIT_") {
            isolatedEnvironment.removeValue(forKey: key)
        }
        isolatedEnvironment["GIT_CONFIG_SYSTEM"] = systemConfigurationURL.normalizedFilePath
        isolatedEnvironment["GIT_CONFIG_GLOBAL"] = configurationURL.normalizedFilePath
        isolatedEnvironment["GIT_TERMINAL_PROMPT"] = "0"
        isolatedEnvironment["HOME"] = homeURL.normalizedFilePath
        isolatedEnvironment["LANG"] = "C"
        isolatedEnvironment["LC_ALL"] = "C"
        isolatedEnvironment["XDG_CONFIG_HOME"] = xdgConfigurationURL.normalizedFilePath
        environment = isolatedEnvironment

        do {
            _ = try git(
                [
                    "config", "--file", systemConfigurationURL.normalizedFilePath,
                    "http.proxy", "http://system.example.invalid:8080",
                ]
            )
            _ = try git(["config", "--global", "user.name", "Colofa Tests"])
            _ = try git(["config", "--global", "user.email", "colofa-tests@example.invalid"])
            _ = try git(["config", "--global", "init.defaultBranch", "main"])
        } catch {
            remove()
            throw error
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func createWorkingRepository(named name: String = "working") throws -> URL {
        let repositoryURL = rootURL.appending(path: name, directoryHint: .isDirectory)
        _ = try git(["init", "--initial-branch=main", repositoryURL.normalizedFilePath])
        return repositoryURL
    }

    func createBareRemote(named name: String = "remote.git") throws -> URL {
        let remoteURL = rootURL.appending(path: name, directoryHint: .isDirectory)
        _ = try git(["init", "--bare", "--initial-branch=main", remoteURL.normalizedFilePath])
        return remoteURL
    }

    func addRemote(_ remoteURL: URL, named name: String, to repositoryURL: URL) throws {
        _ = try git(
            ["remote", "add", name, remoteURL.normalizedFilePath],
            in: repositoryURL
        )
    }

    @discardableResult
    func createCommit(
        in repositoryURL: URL,
        named name: String = "README.md"
    ) throws -> String {
        let fileURL = repositoryURL.appending(path: name)
        try Data("Colofa integration fixture\n".utf8).write(to: fileURL)
        _ = try git(["add", "--", name], in: repositoryURL)
        _ = try git(["commit", "-m", "Fixture commit"], in: repositoryURL)
        return try git(["rev-parse", "HEAD"], in: repositoryURL)
    }

    func createLinkedWorktree(from repositoryURL: URL) throws -> URL {
        let worktreeURL = rootURL.appending(path: "linked", directoryHint: .isDirectory)
        _ = try git(
            ["worktree", "add", "-b", "linked", worktreeURL.normalizedFilePath],
            in: repositoryURL
        )
        return worktreeURL
    }

    func addSubmodule(
        _ sourceURL: URL,
        named name: String,
        to repositoryURL: URL
    ) throws -> URL {
        _ = try git(
            [
                "-c", "protocol.file.allow=always",
                "submodule", "add", sourceURL.normalizedFilePath, name,
            ],
            in: repositoryURL
        )
        return repositoryURL.appending(path: name, directoryHint: .isDirectory)
    }

    func createMutationRecordingGit(at executableURL: URL, eventsURL: URL) throws {
        let script = """
        #!/bin/sh
        if [ "$1" = "--version" ]; then
            echo "git version 2.0.0"
            exit 0
        fi
        echo "$1-start" >> "\(eventsURL.normalizedFilePath)"
        sleep 0.1
        echo "$1-end" >> "\(eventsURL.normalizedFilePath)"
        """
        try Data(script.utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.normalizedFilePath
        )
    }

    @discardableResult
    func git(_ arguments: [String], in directoryURL: URL? = nil) throws -> String {
        try rawGit(arguments, in: directoryURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// HEAD's message exactly as the Commit holds it, with none of the trimming every other
    /// reading applies. Comparing what an Amend did to a message needs those bytes intact.
    func rawCommitMessage(in repositoryURL: URL) throws -> String {
        // `git log` ends its record with a newline the Commit itself does not contain.
        let record = try rawGit(["log", "--max-count=1", "--format=%B"], in: repositoryURL)
        return record.hasSuffix("\n") ? String(record.dropLast()) : record
    }

    private func rawGit(_ arguments: [String], in directoryURL: URL? = nil) throws -> String {
        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = gitURL
        process.arguments = arguments
        process.currentDirectoryURL = directoryURL ?? rootURL
        process.environment = environment
        process.standardOutput = outputPipe
        process.standardError = outputPipe.fileHandleForWriting

        try process.run()
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "GitTestRepository",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        String(decoding: output, as: UTF8.self)
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                ]
            )
        }

        return String(decoding: output, as: UTF8.self)
    }

    private func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
