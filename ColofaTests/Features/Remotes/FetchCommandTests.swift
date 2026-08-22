////
//  FetchCommandTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What Colofa adds to `git fetch`, which is almost nothing: the remote's own configuration is
/// what decides which refs a Fetch downloads and which it leaves alone.
struct FetchCommandTests {
    @Test
    func fetchesOneRemoteByNameAndNothingElse() {
        #expect(FetchCommand.fetch("origin") == ["fetch", "--", "origin"])
    }

    /// The tag refspec is spelled out rather than inherited, and it carries no leading `+`, so a
    /// remote configured with `+refs/tags/*:refs/tags/*` cannot force-update a local tag through
    /// an explicit Fetch Tags.
    @Test
    func fetchTagsNamesTheTagRefspecItself() {
        #expect(
            FetchCommand.fetchTags(from: "origin") == [
                "fetch", "--no-tags", "--no-prune", "--no-prune-tags", "--", "origin",
                "refs/tags/*:refs/tags/*",
            ]
        )
        #expect(!FetchCommand.tagRefspec.hasPrefix("+"))
    }

    /// `fetch.prune` with `fetch.pruneTags` deletes local-only tags whether or not an option
    /// asked for it, so Fetch Tags refuses prune in both of the forms Git reads.
    @Test
    func fetchTagsRefusesAConfiguredPrune() {
        let arguments = FetchCommand.fetchTags(from: "origin")

        #expect(arguments.contains("--no-prune"))
        #expect(arguments.contains("--no-prune-tags"))
    }

    /// Only the tag Fetch is the tag Fetch. A remote's ordinary Fetch keeps inheriting the
    /// remote's own configuration, which is what the user's Git policy is for.
    @Test
    func tellsTheTagFetchFromAnOrdinaryOne() {
        #expect(FetchCommand.isTagFetch(FetchCommand.fetchTags(from: "origin")))
        #expect(!FetchCommand.isTagFetch(FetchCommand.fetch("origin")))
    }

    /// The remote is read from where it sits rather than off the end, because the tag Fetch
    /// carries its refspec after it.
    @Test
    func readsTheRemoteEachCommandContacts() {
        #expect(FetchCommand.remote(of: FetchCommand.fetch("mirror")) == "mirror")
        #expect(FetchCommand.remote(of: FetchCommand.fetchTags(from: "mirror")) == "mirror")
        #expect(FetchCommand.remote(of: ["fetch"]) == nil)
        #expect(FetchCommand.remote(of: ["fetch", "--"]) == nil)
    }

    /// A remote whose name starts like an option is still a remote, so it travels after `--`
    /// rather than into Git's option parser.
    @Test(arguments: ["--upload-pack=evil", "-f", "origin"])
    func separatesTheRemoteNameFromOptions(_ remote: String) {
        let arguments = FetchCommand.fetch(remote)

        #expect(arguments.last == remote)
        #expect(arguments[arguments.count - 2] == "--")
    }

    /// Neither command may force, prune, or widen what Git was already configured to do.
    @Test(arguments: [FetchCommand.fetch("origin"), FetchCommand.fetchTags(from: "origin")])
    func carriesNoOptionThatReplacesOrRemovesARef(_ arguments: [String]) {
        for option in refusedFetchOptions {
            #expect(!arguments.contains(option), "\(arguments) carries \(option)")
        }
    }
}
