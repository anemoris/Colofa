////
//  PushSubmoduleIntegrationTests.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a Push writes when the Repository has submodules, against the real Git CLI.
///
/// A Push is the one command whose effect is on somebody else's copy, and the confirmation names
/// exactly one destination. `push.recurseSubmodules` is configuration that quietly makes that two:
/// Git sends each changed submodule to its own remote as well. Only real Git can prove that
/// Colofa overrules it, because the behaviour lives entirely in Git's own handling of the option.
struct PushSubmoduleIntegrationTests {

    /// The Push writes to the one remote the confirmation showed, and the submodule's own remote
    /// is left exactly as it was.
    @Test
    @MainActor
    func pushNeverWritesToAsubmodulesRemoteEvenWhereGitIsConfiguredTo() async throws {
        let fixture = try GitTestRepository()
        let project = try superprojectWithAsubmodule(fixture)
        let submoduleRemoteHead = try fixture.git(
            ["rev-parse", "refs/heads/main"],
            in: project.submoduleRemoteURL
        )
        try fixture.git(
            ["config", "push.recurseSubmodules", "on-demand"],
            in: project.repositoryURL
        )
        let state = await openedWorkspace(fixture, at: project.repositoryURL)

        await state.beginPush()
        await state.confirmPush()

        #expect(state.repositoryFailure == nil)
        #expect(
            try fixture.git(["rev-parse", "refs/heads/main"], in: project.submoduleRemoteURL)
                == submoduleRemoteHead,
            "The Push wrote to a second remote the confirmation never named"
        )
        #expect(
            try fixture.git(["rev-parse", "refs/heads/main"], in: project.remoteURL)
                == fixture.git(["rev-parse", "HEAD"], in: project.repositoryURL),
            "The Push the user did confirm did not reach its own remote"
        )
    }

    /// `check` refuses the Push outright rather than sending anything, which would make the
    /// superproject's own destination depend on a submodule's. Colofa overrules it for the same
    /// reason it overrules `on-demand`: the Push is about the Ref that was shown.
    @Test
    @MainActor
    func asubmoduleGitWouldRefuseToLeaveBehindDoesNotBlockTheConfirmedPush() async throws {
        let fixture = try GitTestRepository()
        let project = try superprojectWithAsubmodule(fixture)
        try fixture.git(["config", "push.recurseSubmodules", "check"], in: project.repositoryURL)
        let state = await openedWorkspace(fixture, at: project.repositoryURL)

        await state.beginPush()
        await state.confirmPush()

        #expect(state.repositoryFailure == nil)
        #expect(
            try fixture.git(["rev-parse", "refs/heads/main"], in: project.remoteURL)
                == fixture.git(["rev-parse", "HEAD"], in: project.repositoryURL)
        )
    }

    // MARK: - Fixtures

    /// A published superproject whose submodule has a Commit its own remote has never seen, which
    /// is the only state in which `push.recurseSubmodules` has anything to do.
    private func superprojectWithAsubmodule(
        _ fixture: GitTestRepository
    ) throws -> SuperprojectRepository {
        let submoduleRemoteURL = try fixture.createBareRemote(named: "submodule-remote.git")
        let submoduleSourceURL = try fixture.createWorkingRepository(named: "submodule-source")
        try fixture.createCommit(in: submoduleSourceURL)
        try fixture.addRemote(submoduleRemoteURL, named: "origin", to: submoduleSourceURL)
        try fixture.git(["push", "origin", "main"], in: submoduleSourceURL)

        let remoteURL = try fixture.createBareRemote(named: "origin.git")
        let repositoryURL = try fixture.createWorkingRepository(named: "superproject")
        try fixture.createCommit(in: repositoryURL)
        let submoduleURL = try fixture.addSubmodule(
            submoduleRemoteURL,
            named: "sub",
            to: repositoryURL
        )
        try fixture.git(["commit", "-m", "Add the submodule"], in: repositoryURL)
        try fixture.addRemote(remoteURL, named: "origin", to: repositoryURL)
        try fixture.git(["push", "--set-upstream", "origin", "main"], in: repositoryURL)

        // The submodule moves to a Commit its remote does not have, and the superproject records
        // the move. This is what `on-demand` would publish and what `check` would refuse over.
        try commitFile("moved\n", to: "moved.txt", in: submoduleURL, of: fixture)
        try fixture.git(["add", "--", "sub"], in: repositoryURL)
        try fixture.git(["commit", "-m", "Move the submodule"], in: repositoryURL)

        return SuperprojectRepository(
            repositoryURL: repositoryURL,
            remoteURL: remoteURL,
            submoduleRemoteURL: submoduleRemoteURL
        )
    }
}

/// A superproject that can be pushed, and the two remotes a Push of it could reach — only one of
/// which the confirmation ever names.
private struct SuperprojectRepository {
    let repositoryURL: URL
    let remoteURL: URL
    let submoduleRemoteURL: URL
}
