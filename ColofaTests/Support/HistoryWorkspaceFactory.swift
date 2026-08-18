////
//  HistoryWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

let historyRepositoryURL = URL(filePath: "/tmp/colofa-history-tests")

/// A Commit built from an index, so a fixture reads as a position in History rather than as a
/// wall of fields.
func historyCommit(
    _ index: Int,
    prefix: String = "c",
    parents: [String]? = nil,
    refLabels: [HistoryRefLabel] = [],
    isShallowBoundary: Bool = false
) -> HistoryCommit {
    let objectID = historyObjectID(index, prefix: prefix)
    return HistoryCommit(
        objectID: objectID,
        abbreviatedObjectID: String(objectID.prefix(7)),
        parentObjectIDs: parents ?? [historyObjectID(index + 1, prefix: prefix)],
        summary: "Commit \(index)",
        authorName: "Colofa Tests",
        authorEmail: "colofa-tests@example.invalid",
        authoredDate: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - index * 60)),
        committerName: "Colofa Tests",
        committerEmail: "colofa-tests@example.invalid",
        committedDate: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - index * 60)),
        refLabels: refLabels,
        isShallowBoundary: isShallowBoundary
    )
}

func historyObjectID(_ index: Int, prefix: String = "c") -> String {
    let digits = String(index)
    let seed = prefix + String(repeating: "0", count: 6 - digits.count) + digits
    return seed + String(repeating: "0", count: 40 - seed.count)
}

func historyCommits(_ count: Int, prefix: String = "c") -> [HistoryCommit] {
    (0..<count).map { historyCommit($0, prefix: prefix) }
}

func historyRepositorySnapshot(
    at url: URL = historyRepositoryURL,
    head: RepositoryHead = .branch("main")
) -> RepositorySnapshot {
    RepositorySnapshot(
        name: url.lastPathComponent,
        rootURL: url,
        gitDirectoryURL: url.appending(path: ".git"),
        head: head,
        localBranches: ["feature", "main"],
        remoteBranches: ["origin/main"],
        tags: ["v1.0"]
    )
}

@MainActor
func historyWorkspace(
    _ stub: RepositoryServiceStub,
    pasteboard: PasteboardRecorder = PasteboardRecorder(),
    at url: URL = historyRepositoryURL
) async -> WorkspaceState {
    let state = WorkspaceState(
        repositoryService: stub.service,
        pasteboard: pasteboard.writer,
        launchArguments: ["--ui-testing"]
    )
    await state.handleRepositorySelection(.success(url))
    #expect(state.repository != nil)
    return state
}

/// A stub whose History covers every Ref type, both walks, and more than one standard page.
///
/// Shared by the History suites so a case about the Store says only what it changes.
func historyStub(
    head: RepositoryHead = .branch("main"),
    historyFailingOffsets: Set<Int> = [],
    snapshots: [RepositorySnapshot]? = nil,
    urls: [URL] = [historyRepositoryURL]
) -> RepositoryServiceStub {
    let states = snapshots ?? [historyRepositorySnapshot(head: head)]
    return RepositoryServiceStub(
        snapshots: Dictionary(
            uniqueKeysWithValues: urls.map { url in
                (url, states.map { historyRepositorySnapshot($0, at: url) })
            }
        ),
        historyCommits: [
            .head: historyMainCommits,
            .localBranch("main"): historyMainCommits,
            .localBranch("feature"): (0..<3).map { historyNamedCommit("Feature", $0, "f") },
            .remoteBranch("origin/main"): (0..<3).map { historyNamedCommit("Remote", $0, "r") },
            .tag("v1.0"): (0..<3).map { historyNamedCommit("Tag", $0, "t") },
        ],
        firstParentCommits: [
            .head: historyFirstParentCommits,
            .localBranch("main"): historyFirstParentCommits,
        ],
        historyFailingOffsets: historyFailingOffsets
    )
}

/// More than one standard page, so Load More has a real boundary to cross.
let historyMainCommits = (0..<250).map { historyNamedCommit("Main", $0, "m") }

/// The same walk minus the one Commit only a merge's second parent reaches, which is the
/// difference `--first-parent` makes.
let historyFirstParentCommits = historyMainCommits.filter {
    $0.objectID != historyObjectID(1, prefix: "m")
}

func historyNamedCommit(_ name: String, _ index: Int, _ prefix: String) -> HistoryCommit {
    let commit = historyCommit(index, prefix: prefix)
    return HistoryCommit(
        objectID: commit.objectID,
        abbreviatedObjectID: commit.abbreviatedObjectID,
        parentObjectIDs: commit.parentObjectIDs,
        summary: "\(name) \(index)",
        authorName: commit.authorName,
        authorEmail: commit.authorEmail,
        authoredDate: commit.authoredDate,
        committerName: commit.committerName,
        committerEmail: commit.committerEmail,
        committedDate: commit.committedDate,
        refLabels: commit.refLabels,
        isShallowBoundary: commit.isShallowBoundary
    )
}

/// The same Repository state reported at another location, which is how a test gives one stub
/// two Repositories that report the same Refs.
func historyRepositorySnapshot(
    _ snapshot: RepositorySnapshot,
    at url: URL
) -> RepositorySnapshot {
    RepositorySnapshot(
        name: url.lastPathComponent,
        rootURL: url,
        gitDirectoryURL: url.appending(path: ".git"),
        head: snapshot.head,
        localBranches: snapshot.localBranches,
        remoteBranches: snapshot.remoteBranches,
        tags: snapshot.tags
    )
}
