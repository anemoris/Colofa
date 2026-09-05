////
//  GitMissingHelperTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Reading a program Git could not run out of the failure it reported instead.
struct GitMissingHelperTests {

    /// The failure as it was actually reported: the filter died, the pipe closed, and Git blamed
    /// the far end. Only the first line says what happened.
    @Test
    func namesTheFilterProgramBehindARemoteThatHungUp() {
        let detected = GitMissingHelper.detect(
            in: """
            git-lfs filter-process: git-lfs: command not found
            fatal: the remote end hung up unexpectedly
            """
        )

        #expect(detected == GitMissingHelper(program: "git-lfs"))
    }

    @Test
    func readsTheNameFromEitherShellSpelling() {
        #expect(
            GitMissingHelper.detect(in: "sh: line 1: git-lfs: command not found")
                == GitMissingHelper(program: "git-lfs")
        )
        #expect(
            GitMissingHelper.detect(in: "zsh:1: command not found: git-lfs")
                == GitMissingHelper(program: "git-lfs")
        )
    }

    @Test
    func namesAProgramGitCouldNotExecuteItself() {
        #expect(
            GitMissingHelper.detect(
                in: "error: cannot run git-credential-manager: No such file or directory"
            ) == GitMissingHelper(program: "git-credential-manager")
        )
        #expect(
            GitMissingHelper.detect(in: "fatal: cannot spawn git-lfs: No such file or directory")
                == GitMissingHelper(program: "git-lfs")
        )
    }

    /// Colofa builds its own argument lists, so a subcommand Git does not know is a program Git
    /// looked for on `PATH` and did not find.
    @Test
    func namesTheProgramBehindASubcommandGitDoesNotHave() {
        let detected = GitMissingHelper.detect(
            in: "git: 'lfs' is not a git command. See 'git --help'."
        )

        #expect(detected == GitMissingHelper(program: "git-lfs"))
    }

    @Test
    func namesTheProgramBehindATransportGitDoesNotCarry() {
        let detected = GitMissingHelper.detect(
            in: "fatal: Unable to find remote helper for 'hg'"
        )

        #expect(detected == GitMissingHelper(program: "git-remote-hg"))
    }

    /// A path Git was handed outright was found and then failed for its own reasons. Advice about
    /// installing a program would be answering a different question.
    @Test
    func ignoresAProgramGitDidNotLookForOnTheSearchPath() {
        let detected = GitMissingHelper.detect(
            in: "error: cannot run .git/hooks/pre-commit: No such file or directory"
        )

        #expect(detected == nil)
    }

    /// A program Git found and was refused is not a program that is missing.
    @Test
    func ignoresAProgramThatWasFoundAndRefused() {
        let detected = GitMissingHelper.detect(in: "error: cannot run git-lfs: Permission denied")

        #expect(detected == nil)
    }

    /// Failure details reach this already redacted. What redaction left behind is not a program
    /// name, and offering it as one would put Colofa's own placeholder in an alert.
    @Test
    func ignoresWhatRedactionLeftBehind() {
        #expect(GitMissingHelper.detect(in: "sh: <Repository>: command not found") == nil)
        #expect(GitMissingHelper.detect(in: "sh: <Sensitive Input>: command not found") == nil)
    }

    @Test
    func saysNothingAboutFailuresThatNameNoProgram() {
        #expect(GitMissingHelper.detect(in: "") == nil)
        #expect(
            GitMissingHelper.detect(in: "! [rejected] main -> main (non-fast-forward)") == nil
        )
        #expect(GitMissingHelper.detect(in: "fatal: Host key verification failed.") == nil)
        #expect(
            GitMissingHelper.detect(in: "fatal: the remote end hung up unexpectedly") == nil
        )
    }
}
