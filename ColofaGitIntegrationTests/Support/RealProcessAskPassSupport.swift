////
//  RealProcessAskPassSupport.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Where the real programs these tests drive live.
///
/// Named rather than searched for: what is under test is Colofa's channel against the Git and
/// OpenSSH macOS ships, and a different one found on a developer's `PATH` would be a different
/// boundary.
nonisolated enum InstalledTool {
    static let git = URL(filePath: "/usr/bin/git")
    static let sshKeygen = URL(filePath: "/usr/bin/ssh-keygen")

    /// Skips the calling test when the tool is not installed, rather than reporting the absence of
    /// a system program as a failure of Colofa's.
    static func require(_ toolURL: URL) throws {
        try #require(
            FileManager.default.isExecutableFile(atPath: toolURL.normalizedFilePath),
            "\(toolURL.lastPathComponent) is not installed on this machine"
        )
    }
}

/// Runs a real program to completion with a controlled environment.
///
/// - Returns: What it exited with and what it printed. Standard error is discarded: these tools
///   write progress and warnings there, and what is under test is the answer.
nonisolated func runTool(
    _ executableURL: URL,
    _ arguments: [String],
    environment: [String: String],
    in directoryURL: URL? = nil
) throws -> (status: Int32, output: String) {
    let pipe = Pipe()
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.environment = environment
    process.currentDirectoryURL = directoryURL
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    try process.run()
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(gitBytes: output))
}

/// A real Git credential helper, written the way Git's credential protocol expects one.
///
/// Git runs it with the operation as its first argument and the request on standard input, and
/// reads `username` and `password` lines back. Nothing here stands in for Git's own ordering: what
/// is being proved is that Git consults this before it ever reaches an AskPass program, so the
/// helper has to be one Git actually accepts.
nonisolated func writeGitCredentialHelper(
    at executableURL: URL,
    username: String,
    password: String,
    reporting invocationsURL: URL
) throws {
    try writeExecutable(
        at: executableURL,
        script: """
        echo "$1" >> "\(invocationsURL.normalizedFilePath)"
        if [ "$1" = "get" ]; then
            printf 'username=%s\\n' \(username.debugDescription)
            printf 'password=%s\\n' \(password.debugDescription)
        fi
        exit 0
        """
    )
}

/// What a Basic `Authorization` header carries for these credentials, so a test compares the
/// credential rather than the encoding.
nonisolated func basicAuthorization(username: String, password: String) -> String {
    "Basic \(Data("\(username):\(password)".utf8).base64EncodedString())"
}
