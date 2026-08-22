////
//  FetchIntegrationSupport.swift
//  ColofaGitIntegrationTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// A bare remote holding one commit on `main`, the repository that publishes to it, and a clone
/// of it to fetch into.
///
/// Shared by the Fetch and Fetch Tags suites so both start from the same uninteresting state and
/// only spell out what their own case changes.
struct PublishedRepository {
    let remoteURL: URL
    let publisherURL: URL
    let cloneURL: URL
}

func publishedRepository(_ fixture: GitTestRepository) throws -> PublishedRepository {
    let remoteURL = try fixture.createBareRemote()
    let publisherURL = try fixture.createWorkingRepository(named: "publisher")
    try fixture.createCommit(in: publisherURL)
    try fixture.addRemote(remoteURL, named: "origin", to: publisherURL)
    try fixture.git(["push", "origin", "main"], in: publisherURL)
    return PublishedRepository(
        remoteURL: remoteURL,
        publisherURL: publisherURL,
        cloneURL: try fixture.createClone(of: remoteURL, named: "clone")
    )
}

@discardableResult
func commitFile(
    _ contents: String,
    to path: String,
    in repositoryURL: URL,
    of fixture: GitTestRepository
) throws -> String {
    try Data(contents.utf8).write(to: repositoryURL.appending(path: path))
    try fixture.git(["add", "--", path], in: repositoryURL)
    try fixture.git(["commit", "-m", "Add \(path)"], in: repositoryURL)
    return try fixture.git(["rev-parse", "HEAD"], in: repositoryURL)
}
