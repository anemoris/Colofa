////
//  BranchNameValidationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Testing
@testable import Colofa

struct BranchNameValidationTests {
    @Test
    func reportsNothingBeforeAnythingIsTyped() {
        #expect(
            BranchNameValidation.evaluate(
                name: "",
                existingLocalBranches: ["main"],
                isFormatValid: nil
            ) == .empty
        )
    }

    /// A name Git has not answered about yet is not a name Colofa creates, and it is not a
    /// mistake to report either.
    @Test
    func waitsForGitBeforeAcceptingAName() {
        let validation = BranchNameValidation.evaluate(
            name: "feature",
            existingLocalBranches: ["main"],
            isFormatValid: nil
        )

        #expect(validation == .checking)
        #expect(validation.message == nil)
        #expect(!validation.allowsCreation)
    }

    @Test
    func acceptsAnameGitAccepts() {
        let validation = BranchNameValidation.evaluate(
            name: "feature/work",
            existingLocalBranches: ["main"],
            isFormatValid: true
        )

        #expect(validation == .valid)
        #expect(validation.allowsCreation)
        #expect(validation.message == nil)
    }

    @Test
    func refusesAnameGitRefuses() {
        let validation = BranchNameValidation.evaluate(
            name: "bad name",
            existingLocalBranches: [],
            isFormatValid: false
        )

        #expect(validation == .invalidFormat)
        #expect(validation.message != nil)
        #expect(!validation.allowsCreation)
    }

    /// A branch that already exists is a fact the Repository already reported, so it is answered
    /// without waiting for Git.
    @Test
    func reportsAnExistingBranchWithoutAskingGit() {
        let validation = BranchNameValidation.evaluate(
            name: "main",
            existingLocalBranches: ["main"],
            isFormatValid: nil
        )

        #expect(validation == .alreadyExists)
        #expect(validation.message != nil)
        #expect(!validation.allowsCreation)
    }

    /// `git branch` refuses a name shaped like an option however well formed the refname is, and
    /// it is refused here before Git's own option parser could ever read it.
    @Test(arguments: ["-force", "-", "--all"])
    func refusesAnameThatLooksLikeAnOption(_ name: String) {
        #expect(
            BranchNameValidation.evaluate(
                name: name,
                existingLocalBranches: [],
                isFormatValid: true
            ) == .invalidFormat
        )
    }
}
