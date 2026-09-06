////
//  MergeSourceTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation
import Testing
@testable import Colofa

/// Which Refs a Merge acts on, and what it asks Git to merge.
struct MergeSourceTests {
    @Test
    func aLocalBranchIsMergedByItsFullRefname() throws {
        let source = try #require(MergeSource.resolve(.localBranch("feature/真实")))

        #expect(source.name == "feature/真实")
        #expect(source.revision == "refs/heads/feature/真实")
        #expect(!source.isRemote)
        #expect(source.commitMessage == "Merge branch 'feature/真实'")
    }

    /// A Remote-tracking Branch is an ordinary Merge source; only the Commit message says so.
    @Test
    func aRemoteBranchIsMergedAndNamedAsOne() throws {
        let source = try #require(MergeSource.resolve(.remoteBranch("origin/main")))

        #expect(source.revision == "refs/remotes/origin/main")
        #expect(source.isRemote)
        #expect(source.commitMessage == "Merge remote-tracking branch 'origin/main'")
    }

    /// Merging a tag is not the workflow this app is about, and HEAD is already the Branch being
    /// merged into. Answering `nil` is what keeps Merge out of their menus entirely.
    @Test(arguments: [GitReference.tag("v1.0"), .head])
    func aRefThatIsNotABranchOffersNoMerge(reference: GitReference) {
        #expect(MergeSource.resolve(reference) == nil)
    }
}
