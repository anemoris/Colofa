////
//  GitConfigurationReaderTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Which entries the two configuration reads are allowed to offer for editing.
///
/// A scope names a precedence level, not a file. Git reads `~/.gitconfig` and
/// `$XDG_CONFIG_HOME/git/config` as one global scope but writes to only one of them, so the file
/// an entry came from decides whether Colofa may rewrite or remove it.
struct GitConfigurationReaderTests {
    private let homeConfig = "/Users/test/.gitconfig"
    private let xdgConfig = "/Users/test/.config/git/config"

    /// Answers each read with the output it asked for, so one fixture can describe a Repository
    /// whose effective values and literal files differ.
    private func snapshot(
        effective: String,
        direct: String,
        globalWriteTarget: String?
    ) async throws -> GitConfigurationSnapshot {
        try await GitConfigurationReader.snapshot(globalWriteTarget: globalWriteTarget) { arguments in
            Data((arguments == GitConfigurationReader.directArguments ? direct : effective).utf8)
        }
    }

    /// Reproduces the case Git answers with exit status 5: the value is global, it is real, it is
    /// the effective one — and `git config --global --unset-all` cannot touch it, because the
    /// write goes to `~/.gitconfig` instead. Colofa shows it as a source rather than as a field
    /// the user can clear.
    @Test
    func aGlobalValueFromAnotherGlobalFileIsShownButNotEditable() async throws {
        let output = "global\0file:\(xdgConfig)\0user.email\nxdg@example.invalid\0"
        let configuration = try await snapshot(
            effective: output,
            direct: output,
            globalWriteTarget: homeConfig
        )

        #expect(configuration.effectiveEntry(for: .userEmail)?.value == "xdg@example.invalid")
        #expect(!configuration.hasEditableEntry(for: .userEmail, editing: .global))
        #expect(configuration.editableValue(for: .userEmail, editing: .global) == nil)

        // Still reported, and reported as what it is: a value another source decides.
        let relationship = configuration.relationship(for: .userEmail, editing: .global)
        #expect(relationship == .shadowedBy(
            GitConfigurationEntry(
                key: .userEmail,
                value: "xdg@example.invalid",
                scope: .global,
                origin: GitConfigurationOrigin(rawValue: "file:\(xdgConfig)")
            ),
            removableScope: nil
        ))
    }

    /// The same value in the file Git actually writes to stays fully editable, which is the
    /// ordinary case and must not be narrowed by the rule above.
    @Test
    func aGlobalValueFromTheWrittenFileStaysEditable() async throws {
        let output = "global\0file:\(homeConfig)\0user.email\nhome@example.invalid\0"
        let configuration = try await snapshot(
            effective: output,
            direct: output,
            globalWriteTarget: homeConfig
        )

        #expect(configuration.hasEditableEntry(for: .userEmail, editing: .global))
        #expect(
            configuration.editableValue(for: .userEmail, editing: .global)
                == "home@example.invalid"
        )
        #expect(configuration.relationship(for: .userEmail, editing: .global) == nil)
    }

    /// Git reports the path it was handed rather than a canonical one, so the comparison is
    /// between locations rather than between strings.
    @Test
    func matchesTheWrittenFileThroughADifferentSpellingOfTheSamePath() async throws {
        let output = "global\0file:/Users/test/./.gitconfig\0user.name\nName\0"
        let configuration = try await snapshot(
            effective: output,
            direct: output,
            globalWriteTarget: homeConfig
        )

        #expect(configuration.hasEditableEntry(for: .userName, editing: .global))
    }

    /// Two different files under one home directory are still two files, which is the whole
    /// point: the XDG one is read by Git and written by nothing Colofa can ask for.
    @Test
    func doesNotMatchAdifferentFileInTheSameDirectory() async throws {
        let output = "global\0file:/Users/test/.gitconfig.local\0user.name\nName\0"
        let configuration = try await snapshot(
            effective: output,
            direct: output,
            globalWriteTarget: homeConfig
        )

        #expect(!configuration.hasEditableEntry(for: .userName, editing: .global))
    }

    /// One Repository has one `.git/config`, so a local entry needs no such comparison — and a
    /// system entry is never Colofa's to write.
    @Test
    func localEntriesStayEditableAndSystemEntriesNeverAre() async throws {
        let output = "system\0file:/etc/gitconfig\0user.name\nSystem\0"
            + "local\0file:.git/config\0user.email\nlocal@example.invalid\0"
        let configuration = try await snapshot(
            effective: output,
            direct: output,
            globalWriteTarget: homeConfig
        )

        #expect(configuration.hasEditableEntry(for: .userEmail, editing: .repository))
        #expect(!configuration.hasEditableEntry(for: .userName, editing: .global))
        #expect(!configuration.hasEditableEntry(for: .userName, editing: .repository))
    }

    /// A value that only exists because an `include.path` pulled it in lives in a file Colofa was
    /// never asked to write, so it stays visible and read-only however its scope is reported.
    @Test
    func anIncludedValueIsNeverEditableEvenAtTheWrittenScope() async throws {
        let configuration = try await snapshot(
            effective: "global\0file:/Users/test/included.gitconfig\0user.name\nIncluded\0",
            direct: "",
            globalWriteTarget: homeConfig
        )

        #expect(configuration.effectiveEntry(for: .userName)?.value == "Included")
        #expect(!configuration.hasEditableEntry(for: .userName, editing: .global))
    }

    /// With no global file to write to, nothing global may be offered as editable: a field the
    /// user can clear has to correspond to a command Git will accept.
    @Test
    func nothingGlobalIsEditableWithoutAwriteTarget() async throws {
        let output = "global\0file:\(homeConfig)\0user.email\nhome@example.invalid\0"
        let configuration = try await snapshot(
            effective: output,
            direct: output,
            globalWriteTarget: nil
        )

        #expect(!configuration.hasEditableEntry(for: .userEmail, editing: .global))
    }
}
