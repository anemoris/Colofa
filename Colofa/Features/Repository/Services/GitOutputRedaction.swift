////
//  GitOutputRedaction.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Removes from Git's own words the two things Colofa must never repeat back: where the
/// Repository is, and anything the user typed into a command.
///
/// This text reaches the user's screen and Colofa's stored error state, so it is redacted at the
/// point failure details are built rather than wherever they are displayed.
nonisolated enum GitOutputRedaction {

    /// What one failed command reports, with the Repository's location and every sensitive value
    /// already removed from both halves of it.
    ///
    /// Built here rather than where the failure was noticed, because this is the only place that
    /// knows what must not survive into it.
    ///
    /// - Parameter output: What Git wrote, bounded so a command that failed loudly cannot carry
    ///   an unbounded diagnostic into the app's error state.
    static func failureDetails(
        of arguments: [String],
        in directoryURL: URL,
        sensitiveValues: [String],
        output: String,
        exitStatus: Int32?
    ) -> GitFailureDetails {
        GitFailureDetails(
            command: redacting(
                (["git"] + arguments).map(\.debugDescription).joined(separator: " "),
                of: directoryURL,
                sensitiveValues: sensitiveValues
            ),
            output: String(
                redacting(
                    output.replacing("\0", with: ""),
                    of: directoryURL,
                    sensitiveValues: sensitiveValues
                ).prefix(outputLimit)
            ),
            exitStatus: exitStatus
        )
    }

    /// How much of what Git wrote a failure carries.
    private static let outputLimit = 4_000

    private static func redacting(
        _ text: String,
        of directoryURL: URL,
        sensitiveValues: [String]
    ) -> String {
        redactingLocation(
            of: directoryURL,
            in: redactingSensitiveValues(sensitiveValues, in: text)
        )
    }

    /// Every spelling of the location is replaced, longest first. Git and hooks report the
    /// canonical path, which on macOS differs from the one the user selected whenever a symlink
    /// such as `/tmp` is involved; without the canonical form that real location would survive.
    static func redactingLocation(of repositoryURL: URL, in text: String) -> String {
        let canonicalPath = try? repositoryURL
            .resourceValues(forKeys: [.canonicalPathKey])
            .canonicalPath
        let paths = Set([repositoryURL.normalizedFilePath, canonicalPath].compactMap { $0 })

        return paths.sorted { $0.count > $1.count }.reduce(text) { redacted, path in
            redacted.replacing(path, with: "<Repository>")
        }
    }

    static func redactingSensitiveValues(_ values: [String], in text: String) -> String {
        values.reduce(text) { redacted, value in
            redactingSensitiveValue(value, in: redacted)
        }
    }

    /// Every form of the standard input a command was fed, longest first, so a message quoting
    /// part of it cannot leave the rest behind.
    static func sensitiveValues(from input: String?) -> [String] {
        guard let input else {
            return []
        }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = input.split(whereSeparator: \.isNewline).map(String.init)
        return Set([input, trimmed] + lines)
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
    }

    private static func redactingSensitiveValue(_ value: String, in text: String) -> String {
        let replacement = "<Sensitive Input>"
        var redacted = text
        var searchStart = redacted.startIndex

        while let range = redacted.range(of: value, range: searchStart..<redacted.endIndex) {
            let characterBefore = range.lowerBound == redacted.startIndex
                ? nil
                : redacted[redacted.index(before: range.lowerBound)]
            let characterAfter = range.upperBound == redacted.endIndex
                ? nil
                : redacted[range.upperBound]
            guard isBoundary(characterBefore), isBoundary(characterAfter) else {
                searchStart = range.upperBound
                continue
            }

            redacted.replaceSubrange(range, with: replacement)
            searchStart = redacted.index(range.lowerBound, offsetBy: replacement.count)
        }
        return redacted
    }

    /// Only a whole word is redacted, so a Commit message of "fix" does not blank out every
    /// occurrence of those letters inside unrelated words in Git's answer.
    private static func isBoundary(_ character: Character?) -> Bool {
        guard let character else {
            return true
        }
        return !character.isLetter && !character.isNumber && character != "_"
    }
}
