#!/usr/bin/env swift

import Foundation

private let baselineName = "Baseline.json"
private let repositoryPrefix = "repo:///"

private enum ScriptError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case let .message(value): value
        }
    }
}

private func swiftLintVersion() throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swiftlint", "version"]
    process.standardOutput = output
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw ScriptError.message("Unable to run SwiftLint.")
    }

    let data = output.fileHandleForReading.readDataToEndOfFile()
    guard let version = String(data: data, encoding: .utf8) else {
        throw ScriptError.message("SwiftLint returned an invalid version string.")
    }
    return version.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func runSwiftLint(arguments: [String]) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swiftlint", "lint"] + arguments
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

private func rewriteFiles(
    in value: Any,
    transform: (String) throws -> String
) throws -> Any {
    if let values = value as? [Any] {
        return try values.map { try rewriteFiles(in: $0, transform: transform) }
    }

    guard let values = value as? [String: Any] else {
        return value
    }

    return try values.reduce(into: [String: Any]()) { result, entry in
        if entry.key == "file", let file = entry.value as? String {
            result[entry.key] = try transform(file)
        } else {
            result[entry.key] = try rewriteFiles(in: entry.value, transform: transform)
        }
    }
}

private func readJSON(at url: URL) throws -> Any {
    try JSONSerialization.jsonObject(with: Data(contentsOf: url))
}

private func writeJSON(_ value: Any, to url: URL) throws {
    var data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0A)
    try data.write(to: url, options: .atomic)
}

/// Rewrites SwiftLint's own locations into the committed `repo:///` form.
///
/// SwiftLint has written both plain paths and `file://` URLs across versions, and a plain path may
/// itself be absolute or already relative to the repository root the lint ran from. All three
/// describe the same file, so all three are accepted and only one is ever written.
private func portableBaseline(from nativeURL: URL, repositoryURL: URL) throws -> Any {
    let root = repositoryURL.path + "/"
    return try rewriteFiles(in: readJSON(at: nativeURL)) { file in
        let path = file.hasPrefix("file://") ? URL(string: file)?.path : file
        guard let path, !path.isEmpty else {
            throw ScriptError.message("Baseline contains an invalid file location.")
        }

        guard path.hasPrefix("/") else {
            return repositoryPrefix + path
        }
        guard path.hasPrefix(root) else {
            throw ScriptError.message("Baseline contains a file outside the repository.")
        }

        return repositoryPrefix + path.dropFirst(root.count)
    }
}

private func nativeBaseline(from portableURL: URL, repositoryURL: URL) throws -> Any {
    try rewriteFiles(in: readJSON(at: portableURL)) { file in
        guard file.hasPrefix(repositoryPrefix) else {
            throw ScriptError.message("Baseline contains a non-portable file path.")
        }

        let relativePath = String(file.dropFirst(repositoryPrefix.count))
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !components.contains("..") else {
            throw ScriptError.message("Baseline contains an invalid repository-relative path.")
        }

        // A plain path rather than a `file://` URL: SwiftLint matches a baseline entry against
        // the location it reports for the file, and it reports a path.
        return repositoryURL.appending(path: relativePath).path
    }
}

private func validateSwiftLintVersion(at versionURL: URL) throws {
    let requiredVersion = try String(contentsOf: versionURL, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let installedVersion = try swiftLintVersion()
    guard installedVersion == requiredVersion else {
        throw ScriptError.message(
            "SwiftLint version mismatch: required \(requiredVersion), found \(installedVersion)."
        )
    }
}

private func main() throws -> Int32 {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.isEmpty || arguments == ["--write-baseline"] else {
        throw ScriptError.message("Usage: swift Scripts/swiftlint.swift [--write-baseline]")
    }

    let fileManager = FileManager.default
    let repositoryURL = URL(
        fileURLWithPath: fileManager.currentDirectoryPath,
        isDirectory: true
    )
    let versionURL = repositoryURL.appending(path: ".swiftlint-version")
    let configURL = repositoryURL.appending(path: ".swiftlint.yml")
    guard fileManager.fileExists(atPath: versionURL.path),
          fileManager.fileExists(atPath: configURL.path) else {
        throw ScriptError.message("Run this command from the repository root.")
    }

    try validateSwiftLintVersion(at: versionURL)

    let temporaryURL = fileManager.temporaryDirectory
        .appending(path: "SwiftLintBaseline-\(UUID().uuidString).json")
    defer { try? fileManager.removeItem(at: temporaryURL) }

    let commonArguments = [
        "--config", configURL.path,
        "--strict",
        "--no-cache",
        "--quiet",
    ]

    if arguments == ["--write-baseline"] {
        let status = try runSwiftLint(
            arguments: commonArguments + ["--write-baseline", temporaryURL.path]
        )
        guard status == 0 || status == 2,
              fileManager.fileExists(atPath: temporaryURL.path) else {
            return status == 0 ? 1 : status
        }

        let baseline = try portableBaseline(
            from: temporaryURL,
            repositoryURL: repositoryURL
        )
        try writeJSON(baseline, to: repositoryURL.appending(path: baselineName))
        return 0
    }

    let baselineURL = repositoryURL.appending(path: baselineName)
    guard fileManager.fileExists(atPath: baselineURL.path) else {
        return try runSwiftLint(arguments: commonArguments)
    }

    let baseline = try nativeBaseline(from: baselineURL, repositoryURL: repositoryURL)
    try writeJSON(baseline, to: temporaryURL)
    return try runSwiftLint(arguments: commonArguments + ["--baseline", temporaryURL.path])
}

do {
    Foundation.exit(try main())
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    Foundation.exit(1)
}
