////
//  FileActionsWorkspaceFactory.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The Repository every file-action suite starts from: one Staged Change, and a tracked path, a
/// Conflict, and an untracked path unstaged — which is every case these actions have to tell
/// apart.
enum FileActionFixture {
    static let modified = RepositoryChange(path: "tracked.txt", kind: .modified)
    static let untracked = RepositoryChange(path: "new.txt", kind: .untracked)
    static let conflicted = RepositoryChange(path: "conflict.txt", kind: .conflict)
    static let staged = RepositoryChange(path: "staged.txt", kind: .modified)

    static func everyKind(at url: URL) -> RepositorySnapshot {
        repository(
            at: url,
            stagedChanges: [staged],
            unstagedChanges: [conflicted, modified, untracked]
        )
    }
}

/// A Store opened on the fixture, with the pasteboard and file system it was given.
///
/// Held together rather than returned loose so a suite reads what a Copy put on the pasteboard
/// and what a Move to Trash asked the file system for without restating the wiring each time.
@MainActor
struct FileActionsWorkspace {
    let state: WorkspaceState
    let stub: RepositoryServiceStub
    let files: FileSystemActionsRecorder
    let pasteboard: PasteboardRecorder
}

extension FileActionsWorkspace {
    /// Answers the open confirmation the way the dialog does: the presentation binding is cleared
    /// first, because SwiftUI clears it while dismissing and before the confirming button's action
    /// runs, and what is then confirmed is the payload the dialog captured when it opened.
    ///
    /// Every suite goes through this rather than calling the Store directly, so none of them can
    /// pass on an ordering the real dialog never produces.
    func confirmPendingFileAction() async {
        guard let action = state.pendingFileAction else {
            Issue.record("No destructive file action was waiting for a confirmation")
            return
        }
        state.isConfirmingFileAction = false
        await state.confirmFileAction(action)
    }
}

@MainActor
func fileActionsWorkspace(
    at repositoryURL: URL,
    defaults: UserDefaults,
    followedBy laterSnapshots: [RepositorySnapshot] = [],
    mutationError: RepositoryOpenError? = nil,
    mutationDelay: Duration? = nil
) async -> FileActionsWorkspace {
    let stub = RepositoryServiceStub(
        snapshots: [
            repositoryURL: [FileActionFixture.everyKind(at: repositoryURL)] + laterSnapshots,
        ],
        mutationError: mutationError,
        mutationDelay: mutationDelay
    )
    let files = FileSystemActionsRecorder()
    let pasteboard = PasteboardRecorder()
    let state = WorkspaceState(
        repositoryService: stub.service,
        pasteboard: pasteboard.writer,
        fileSystem: files.actions,
        userDefaults: defaults,
        launchArguments: ["--ui-testing"]
    )
    await state.handleRepositorySelection(.success(repositoryURL))
    #expect(state.repository != nil)
    return FileActionsWorkspace(
        state: state,
        stub: stub,
        files: files,
        pasteboard: pasteboard
    )
}
