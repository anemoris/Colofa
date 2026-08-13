////
//  UITestingRepositoryService.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

actor UITestingRepositoryService {
    private let arguments: [String]
    private var snapshot: RepositorySnapshot?

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func loadRepository(at url: URL) throws -> RepositorySnapshot {
        if arguments.contains(UITestingArgument.bareRepository) {
            throw RepositoryOpenError.bareRepository
        }
        if let snapshot, snapshot.rootURL == url {
            return snapshot
        }

        let snapshot = initialSnapshot(at: url)
        self.snapshot = snapshot
        return snapshot
    }

    func runMutation(_ command: [String], in repositoryURL: URL) throws {
        if arguments.contains(UITestingArgument.stageFailure) {
            throw RepositoryOpenError.commandFailed(
                GitFailureDetails(command: "git", output: "UI test mutation failed")
            )
        }
        guard let snapshot, snapshot.rootURL == repositoryURL else {
            throw RepositoryOpenError.notRepository
        }

        if command.first == "config" {
            self.snapshot = replacing(
                in: snapshot,
                configuration: configurationMutation(command, in: snapshot.configuration)
            )
            return
        }

        let paths = command.drop { $0 != "--" }.dropFirst()
        var staged = snapshot.stagedChanges
        var unstaged = snapshot.unstagedChanges
        let action = command.drop { $0 == "--literal-pathspecs" }.first
        if action == "add" {
            let changes = unstaged.filter { change in
                !change.isConflict && change.gitPathspecs.contains { paths.contains($0) }
            }
            unstaged.removeAll { changes.contains($0) }
            for change in changes where !staged.contains(change) {
                staged.append(change)
            }
        } else if action == "restore" || action == "rm" {
            let changes = staged.filter { change in
                change.gitPathspecs.contains { paths.contains($0) }
            }
            staged.removeAll { changes.contains($0) }
            for change in changes where !unstaged.contains(change) {
                unstaged.append(change)
            }
        }

        self.snapshot = replacing(
            in: snapshot,
            staged: staged.sorted { $0.path < $1.path },
            unstaged: unstaged.sorted(by: changeOrder)
        )
    }

    private func initialSnapshot(at url: URL) -> RepositorySnapshot {
        guard arguments.contains(UITestingArgument.realRepositoryState) else {
            return RepositorySnapshot(
                name: url.lastPathComponent,
                rootURL: url,
                gitDirectoryURL: url.appending(path: ".git"),
                head: .unbornBranch("main")
            )
        }

        let partial = RepositoryChange(path: "partial 文件.txt", kind: .modified)
        return RepositorySnapshot(
            name: url.lastPathComponent,
            rootURL: url,
            gitDirectoryURL: url.appending(path: ".git"),
            head: arguments.contains(UITestingArgument.detachedHead)
                ? .detached("0123456789abcdef")
                : .branch("main"),
            upstream: RepositoryUpstream(name: "origin/main", ahead: 3, behind: 2),
            remotes: arguments.contains(UITestingArgument.remoteBranchesOnly)
                ? []
                : [RepositoryRemote(name: "origin", url: "ssh://example.invalid/Colofa.git")],
            localBranches: ["feature/真实", "main"],
            remoteBranches: ["origin/main"],
            tags: ["v1.0-测试"],
            stagedChanges: [
                RepositoryChange(path: "added.swift", kind: .added),
                partial,
                RepositoryChange(path: "renamed 名称.txt", kind: .renamed(from: "old name.txt")),
            ],
            unstagedChanges: [
                RepositoryChange(path: "conflict.txt", kind: .conflict),
                RepositoryChange(path: "Link", kind: .typeChanged),
                RepositoryChange(path: "deleted.swift", kind: .deleted),
                RepositoryChange(path: "notes.txt", kind: .untracked),
                partial,
            ],
            operation: operation,
            totalCommitCount: 12,
            gitObjectSize: 4_096,
            configuration: configuration(at: url)
        )
    }

    private func configuration(at url: URL) -> GitConfigurationSnapshot {
        GitConfigurationSnapshot(
            entries: [
                GitConfigurationEntry(
                    key: .httpProxy,
                    value: "http://system.example.invalid:8080",
                    scope: .system,
                    origin: GitConfigurationOrigin(rawValue: "file:/etc/gitconfig")
                ),
                GitConfigurationEntry(
                    key: .userName,
                    value: "Colofa UI Author",
                    scope: .global,
                    origin: GitConfigurationOrigin(rawValue: "file:/tmp/colofa-ui-global.gitconfig")
                ),
                GitConfigurationEntry(
                    key: .userEmail,
                    value: "global@example.invalid",
                    scope: .global,
                    origin: GitConfigurationOrigin(rawValue: "file:/tmp/colofa-ui-global.gitconfig")
                ),
                GitConfigurationEntry(
                    key: .userEmail,
                    value: "local@example.invalid",
                    scope: .local,
                    origin: GitConfigurationOrigin(
                        rawValue: "file:\(url.appending(path: ".git").normalizedFilePath)/config"
                    )
                ),
            ]
        )
    }

    private func configurationMutation(
        _ command: [String],
        in configuration: GitConfigurationSnapshot
    ) -> GitConfigurationSnapshot {
        let scope: GitConfigurationEditScope = command.contains("--global") ? .global : .repository
        guard let key = command.compactMap(GitConfigurationKey.init(rawValue:)).first else {
            return configuration
        }

        // Both write forms replace whatever the scope held, so the scope is cleared first and a
        // value appended only when the command carries one.
        var entries = configuration.entries.filter {
            !($0.key == key && $0.scope == scope.gitScope)
        }
        let isUnset = command.contains { $0.hasPrefix("--unset") }
        if !isUnset,
           let keyIndex = command.firstIndex(of: key.rawValue),
           command.index(after: keyIndex) < command.endIndex {
            let value = command[command.index(after: keyIndex)]
            let origin = scope == .global
                ? GitConfigurationOrigin(rawValue: "file:/tmp/colofa-ui-global.gitconfig")
                : GitConfigurationOrigin(rawValue: "file:.git/config")
            entries.append(
                GitConfigurationEntry(
                    key: key,
                    value: value,
                    scope: scope.gitScope,
                    origin: origin
                )
            )
        }
        entries.sort {
            ($0.scope.precedenceRank ?? Int.max) < ($1.scope.precedenceRank ?? Int.max)
        }
        return GitConfigurationSnapshot(entries: entries)
    }

    private var operation: RepositoryOperation {
        if arguments.contains(UITestingArgument.rebase) {
            .rebase
        } else if arguments.contains(UITestingArgument.am) {
            .am
        } else if arguments.contains(UITestingArgument.cherryPick) {
            .cherryPick
        } else if arguments.contains(UITestingArgument.revert) {
            .revert
        } else {
            .merge
        }
    }

    /// Copies `snapshot`, overriding only the fields a mutation touched.
    ///
    /// `RepositorySnapshot` has no `with`-style API, so every stub mutation would otherwise
    /// restate all of its fields and silently drop whichever one a future property forgot.
    private func replacing(
        in snapshot: RepositorySnapshot,
        staged: [RepositoryChange]? = nil,
        unstaged: [RepositoryChange]? = nil,
        configuration: GitConfigurationSnapshot? = nil
    ) -> RepositorySnapshot {
        RepositorySnapshot(
            name: snapshot.name,
            rootURL: snapshot.rootURL,
            gitDirectoryURL: snapshot.gitDirectoryURL,
            head: snapshot.head,
            upstream: snapshot.upstream,
            remotes: snapshot.remotes,
            localBranches: snapshot.localBranches,
            remoteBranches: snapshot.remoteBranches,
            tags: snapshot.tags,
            stagedChanges: staged ?? snapshot.stagedChanges,
            unstagedChanges: unstaged ?? snapshot.unstagedChanges,
            operation: snapshot.operation,
            totalCommitCount: snapshot.totalCommitCount,
            gitObjectSize: snapshot.gitObjectSize,
            configuration: configuration ?? snapshot.configuration
        )
    }

    private func changeOrder(_ lhs: RepositoryChange, _ rhs: RepositoryChange) -> Bool {
        if lhs.isConflict != rhs.isConflict {
            return lhs.isConflict
        }
        return lhs.path < rhs.path
    }
}
#endif
