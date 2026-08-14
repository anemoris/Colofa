////
//  RepositorySnapshot.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct RepositorySnapshot: Equatable, Identifiable, Sendable {
    let name: String
    let rootURL: URL
    let gitDirectoryURL: URL
    let head: RepositoryHead
    let headCommit: RepositoryHeadCommit?
    let upstream: RepositoryUpstream?
    let remotes: [RepositoryRemote]
    let localBranches: [String]
    let remoteBranches: [String]
    let tags: [String]
    let stagedChanges: [RepositoryChange]
    let unstagedChanges: [RepositoryChange]
    let operation: RepositoryOperation?
    let totalCommitCount: Int
    let gitObjectSize: Int64
    let configuration: GitConfigurationSnapshot
    let changeCount: Int

    nonisolated init(
        name: String,
        rootURL: URL,
        gitDirectoryURL: URL,
        head: RepositoryHead,
        headCommit: RepositoryHeadCommit? = nil,
        upstream: RepositoryUpstream? = nil,
        remotes: [RepositoryRemote] = [],
        localBranches: [String] = [],
        remoteBranches: [String] = [],
        tags: [String] = [],
        stagedChanges: [RepositoryChange] = [],
        unstagedChanges: [RepositoryChange] = [],
        operation: RepositoryOperation? = nil,
        totalCommitCount: Int = 0,
        gitObjectSize: Int64 = 0,
        configuration: GitConfigurationSnapshot = .empty
    ) {
        self.name = name
        self.rootURL = rootURL
        self.gitDirectoryURL = gitDirectoryURL
        self.head = head
        self.headCommit = headCommit
        self.upstream = upstream
        self.remotes = remotes
        self.localBranches = localBranches
        self.remoteBranches = remoteBranches
        self.tags = tags
        self.stagedChanges = stagedChanges
        self.unstagedChanges = unstagedChanges
        self.operation = operation
        self.totalCommitCount = totalCommitCount
        self.gitObjectSize = gitObjectSize
        self.configuration = configuration
        var changedPaths = Set(stagedChanges.map(\.path))
        changedPaths.formUnion(unstagedChanges.map(\.path))
        changeCount = changedPaths.count
    }

    var id: URL { rootURL }
}
