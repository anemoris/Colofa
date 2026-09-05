////
//  GitMissingHelper.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// A program Git looked for on `PATH`, did not find, and could not run — named out of Git's own
/// output.
///
/// Git reports this failure as whatever the interrupted work happened to be, which is rarely what
/// went wrong. A missing `git-lfs` ends a fetch as `the remote end hung up unexpectedly`: the
/// filter process died, the pipe carrying the object stream closed, and Git said the far end was
/// gone. Nothing is wrong with the remote, the repository, or the network, and a user reading that
/// has no path to the real cause.
///
/// Recognizing it is deliberately separate from preventing it. Colofa hands Git a `PATH` that
/// covers the well-known install locations (`GitSearchPath`), which is what stops the common case;
/// a helper that was never installed, or installed somewhere no fixed list can enumerate, still
/// fails, and still deserves to be named.
///
/// Only a bare program name counts. A name Git resolved through `PATH` is the failure this
/// describes; a path Git was handed outright — a hook, an explicitly configured executable — was
/// found and then failed for its own reasons, and answering it with advice about installing a
/// program would be answering a different question.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while the Store
/// reads this from a command that ran off it.
nonisolated struct GitMissingHelper: Equatable, Sendable {

    /// The program Git could not run, exactly as Git or the shell named it.
    let program: String

    /// What `output` says Git could not run, or `nil` when it names no such program — which is
    /// every failure that was about something else.
    static func detect(in output: String) -> Self? {
        for line in output.split(whereSeparator: \.isNewline) {
            if let program = program(reportedIn: line) {
                return Self(program: program)
            }
        }
        return nil
    }

    /// What went wrong and what to do about it, naming the program.
    ///
    /// The advice is deliberately two-sided, because the two remaining causes need different
    /// answers: a program that was never installed has to be installed, and one installed where
    /// no fixed list looks is only reachable through the `PATH` a shell builds.
    var message: LocalizedStringResource {
        .gitMissingHelperDescription(program)
    }

    private static func program(reportedIn line: some StringProtocol) -> String? {
        shellReportedProgram(in: line)
            ?? gitReportedProgram(in: line)
            ?? gitSubcommandProgram(in: line)
            ?? remoteHelperProgram(in: line)
    }

    /// The name a shell could not find.
    ///
    /// Filters, hooks, aliases, and configured helper commands are run through `/bin/sh`, so it is
    /// the shell rather than Git that reports the name — which is why the observed Git LFS failure
    /// reads `git-lfs filter-process: git-lfs: command not found`. Both spellings are read because
    /// the shells disagree about which side of the colon the name goes on.
    private static func shellReportedProgram(in line: some StringProtocol) -> String? {
        if let reported = line.firstRange(of: "command not found: ") {
            return name(line[reported.upperBound...])
        }
        guard line.hasSuffix(": command not found") else {
            return nil
        }
        return name(
            line.dropLast(": command not found".count)
                .split(separator: ":")
                .last ?? ""
        )
    }

    /// The name Git could not execute itself, which is how it reports a helper it ran directly.
    ///
    /// The reason is required rather than assumed: `Permission denied` names a program Git found
    /// and was refused, which is not a program that is missing.
    private static func gitReportedProgram(in line: some StringProtocol) -> String? {
        guard line.hasSuffix(": No such file or directory") else {
            return nil
        }
        let reported = ["cannot run ", "cannot spawn ", "cannot exec "].lazy
            .compactMap { line.firstRange(of: $0) }
            .first
        guard let reported else {
            return nil
        }
        return name(
            line[reported.upperBound...]
                .dropLast(": No such file or directory".count)
        )
    }

    /// The program behind a subcommand Git does not have.
    ///
    /// Git looks for `git-<name>` on `PATH` and says this when it finds none. Colofa builds its
    /// own argument lists, so a subcommand Git does not know is never a typo the user made — it is
    /// exactly this failure, and it is how `git lfs` reports itself.
    private static func gitSubcommandProgram(in line: some StringProtocol) -> String? {
        guard line.hasPrefix("git: '"),
              line.contains("' is not a git command"),
              let subcommand = name(line.dropFirst("git: '".count).prefix { $0 != "'" }) else {
            return nil
        }
        return "git-\(subcommand)"
    }

    /// The program behind a transport Git does not carry, which it looks for as
    /// `git-remote-<transport>` on `PATH`.
    private static func remoteHelperProgram(in line: some StringProtocol) -> String? {
        guard let reported = line.firstRange(of: "Unable to find remote helper for '"),
              let transport = name(line[reported.upperBound...].prefix { $0 != "'" }) else {
            return nil
        }
        return "git-remote-\(transport)"
    }

    /// `reported` when it is a name Git resolved through `PATH`, and `nil` when it is anything
    /// else: an empty field, a path, text that ran together with the rest of a message, or one of
    /// the placeholders redaction left where a location or a secret used to be.
    private static func name(_ reported: some StringProtocol) -> String? {
        let trimmed = reported.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              trimmed.count <= nameLimit,
              !trimmed.contains("/"),
              !trimmed.contains("<"),
              !trimmed.contains(where: \.isWhitespace) else {
            return nil
        }
        return trimmed
    }

    /// Longer than any program name, and short enough that a line Colofa misread cannot put a
    /// paragraph of Git's output into an alert.
    private static let nameLimit = 64
}
