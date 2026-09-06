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

    /// What an unfinished Merge is bringing in, or `nil` when no Merge is unfinished. Published
    /// with the Repository because a Conflict outlives the command that caused it: the labels its
    /// version choices carry have to survive a refresh, a new window, and a relaunch.
    let mergeHead: MergeHead?

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
        mergeHead: MergeHead? = nil,
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
        self.mergeHead = mergeHead
        self.totalCommitCount = totalCommitCount
        self.gitObjectSize = gitObjectSize
        self.configuration = configuration
        var changedPaths = Set(stagedChanges.map(\.path))
        changedPaths.formUnion(unstagedChanges.map(\.path))
        changeCount = changedPaths.count
    }

    var id: URL { rootURL }

    /// Whether the Git directory sits somewhere the user has to be told about.
    ///
    /// In an ordinary Repository it is the working tree plus `/.git`, so showing it repeats the
    /// path directly above it. A worktree, a submodule, or a `--separate-git-dir` clone puts it
    /// elsewhere, and that is a fact no other field carries. Same rule the remote URLs already
    /// follow: two addresses are shown only when they differ.
    var hasSeparateGitDirectory: Bool {
        gitDirectoryURL.normalizedFilePath
            != rootURL.appending(path: ".git").normalizedFilePath
    }

    /// The Refs this read reported, which is what a Ref selection made against an earlier read
    /// has to be checked against.
    var references: RepositoryReferences {
        RepositoryReferences(
            localBranches: localBranches,
            remoteBranches: remoteBranches,
            tags: tags
        )
    }
}
