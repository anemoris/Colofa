////
//  GitReferenceTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct GitReferenceTests {
    /// Every named Ref is spelled in full, so a branch and a tag sharing a name cannot resolve to
    /// whichever one Git's own precedence rule happens to prefer.
    @Test(
        arguments: [
            (GitReference.head, "HEAD"),
            (.localBranch("main"), "refs/heads/main"),
            (.localBranch("feature/真实"), "refs/heads/feature/真实"),
            (.remoteBranch("origin/main"), "refs/remotes/origin/main"),
            (.tag("v1.0"), "refs/tags/v1.0"),
        ]
    )
    func everyRefIsAskedForByItsFullName(_ reference: GitReference, _ revision: String) {
        #expect(reference.revision == revision)
    }

    @Test
    func headNamesWhateverItPointsAtRatherThanItself() {
        #expect(GitReference.head.name == nil)
        #expect(GitReference.head.branchName == nil)
    }

    @Test
    func onlyABranchHasABranchNameToCopy() {
        #expect(GitReference.localBranch("main").branchName == "main")
        #expect(GitReference.remoteBranch("origin/main").branchName == "origin/main")
        #expect(GitReference.tag("v1.0").branchName == nil)
        #expect(GitReference.tag("v1.0").name == "v1.0")
    }

    @Test
    func aRefThatTheRepositoryNoLongerReportsIsGone() {
        let references = RepositoryReferences(
            localBranches: ["main"],
            remoteBranches: ["origin/main"],
            tags: ["v1.0"]
        )

        #expect(GitReference.head.exists(in: references))
        #expect(GitReference.localBranch("main").exists(in: references))
        #expect(!GitReference.localBranch("feature").exists(in: references))
        #expect(GitReference.remoteBranch("origin/main").exists(in: references))
        #expect(!GitReference.remoteBranch("origin/gone").exists(in: references))
        #expect(GitReference.tag("v1.0").exists(in: references))
        #expect(!GitReference.tag("v2.0").exists(in: references))
    }

    /// A branch and a remote-tracking branch of the same name are different Refs, so nothing
    /// keyed on a selection may treat them as one.
    @Test
    func aLocalAndARemoteRefOfTheSameNameAreDifferentSelections() {
        #expect(GitReference.localBranch("main") != GitReference.remoteBranch("main"))
        #expect(GitReference.localBranch("main") != GitReference.tag("main"))
    }
}
