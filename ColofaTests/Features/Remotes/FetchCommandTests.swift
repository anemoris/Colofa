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

    /// The branch refspec is spelled out rather than inherited, which is the whole reason the
    /// prune below is safe to ask for: it replaces whatever `remote.<name>.fetch` holds for this
    /// command only.
    @Test
    func fetchRemotesNamesTheBranchRefspecItself() {
        #expect(
            FetchCommand.fetchRemotes(from: "origin") == [
                "fetch", "--prune", "--no-tags", "--no-prune-tags", "--", "origin",
                "+refs/heads/*:refs/remotes/origin/*",
            ]
        )
    }

    /// The refspec's destination is what bounds the prune, so it has to land under this remote's
    /// own remote-tracking Branches and nowhere else. A Repository configuring
    /// `remote.origin.fetch = +refs/tags/*:refs/tags/*` would otherwise have its local-only tags
    /// deleted by `--prune`, which `--no-prune-tags` does not prevent: that option refuses only
    /// the tag refspec Git adds implicitly.
    @Test(arguments: ["origin", "mirror", "up stream"])
    func fetchRemotesBoundsPruneToThisRemotesOwnTrackingBranches(_ remote: String) {
        let refspec = FetchCommand.remoteBranchRefspec(of: remote)
        let destination = try? #require(refspec.split(separator: ":").last)

        #expect(destination == "refs/remotes/\(remote)/*")
        #expect(FetchCommand.fetchRemotes(from: remote).contains(refspec))
    }

    /// Pruning branches is what was asked for; pruning tags is not, and Git reads that request
    /// from configuration whether or not an option named it.
    @Test
    func fetchRemotesRefusesTagPruning() {
        let arguments = FetchCommand.fetchRemotes(from: "origin")

        #expect(arguments.contains("--prune"))
        #expect(arguments.contains("--no-tags"))
        #expect(arguments.contains("--no-prune-tags"))
        #expect(!arguments.contains("--prune-tags"))
    }

    /// Only the Fetch Remotes prunes. The toolbar's Fetch keeps inheriting the remote's own
    /// configuration, which is what the user's Git policy is for.
    @Test
    func tellsTheRemotesFetchFromAnOrdinaryOne() {
        #expect(FetchCommand.isRemotesFetch(FetchCommand.fetchRemotes(from: "origin")))
        #expect(!FetchCommand.isRemotesFetch(FetchCommand.fetch("origin")))
        #expect(!FetchCommand.isRemotesFetch(FetchCommand.fetchTags(from: "origin")))
        #expect(!FetchCommand.isRemotesFetch(["fetch"]))
    }

    /// A Fetch Remotes that pruned one remote's refs must not be mistaken for a tag Fetch, or the
    /// Store would explain its failure by reading tags it never asked for.
    @Test
    func theRemotesFetchIsNotATagFetch() {
        #expect(!FetchCommand.isTagFetch(FetchCommand.fetchRemotes(from: "origin")))
    }

    /// Fetch Remotes removes refs on purpose, so the shared refusal does not apply to it — but
    /// everything that forces a ref or widens the command beyond the one remote still does.
    @Test
    func fetchRemotesForcesNothingAndWidensNothing() {
        let arguments = FetchCommand.fetchRemotes(from: "origin")

        for option in ["--force", "-f", "--all", "--multiple", "--update-head-ok"] {
            #expect(!arguments.contains(option), "\(arguments) carries \(option)")
        }
    }

    /// The remote is read from where it sits rather than off the end, because the tag Fetch
    /// carries its refspec after it.
    @Test
    func readsTheRemoteEachCommandContacts() {
        #expect(FetchCommand.remote(of: FetchCommand.fetch("mirror")) == "mirror")
        #expect(FetchCommand.remote(of: FetchCommand.fetchTags(from: "mirror")) == "mirror")
        #expect(FetchCommand.remote(of: FetchCommand.fetchRemotes(from: "mirror")) == "mirror")
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

    /// Neither of these may force, prune, or widen what Git was already configured to do. Fetch
    /// Remotes is deliberately not among them: removing a remote-tracking Branch the remote no
    /// longer has is the thing the user asked it for.
    @Test(arguments: [FetchCommand.fetch("origin"), FetchCommand.fetchTags(from: "origin")])
    func carriesNoOptionThatReplacesOrRemovesARef(_ arguments: [String]) {
        for option in refusedFetchOptions {
            #expect(!arguments.contains(option), "\(arguments) carries \(option)")
        }
    }
}
