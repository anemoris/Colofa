////
//  RepositoryOperationBanner.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The unfinished Git operation, said at the top of the middle column rather than in a window.
///
/// A Conflict is a state the user works in, not an event: resolving one means reading files,
/// opening Diffs, and staging paths, all of which a modal would block. The banner stays put,
/// carries the operation's own way out, and leaves the conflicted paths — which the Repository
/// already lists first — visible underneath it.
struct RepositoryOperationBanner: View {
    let operation: RepositoryOperation

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle")
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(.operationInProgressDescription)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("repository.operation")
            Spacer()
            if operation == .merge {
                MergeOperationActions()
            }
        }
        .padding()
        .background(.bar)
    }

    private var title: LocalizedStringResource {
        switch operation {
        case .am: .gitAmInProgress
        case .cherryPick: .cherryPickInProgress
        case .merge: .mergeInProgress
        case .rebase: .rebaseInProgress
        case .revert: .revertInProgress
        }
    }
}

/// The two ways out of an unfinished Merge.
///
/// Continue stays disabled until every unmerged path is resolved, so the operation cannot be
/// finished over a Conflict nobody decided. Abort is Git's own merge rollback rather than
/// anything Colofa assembles, so the Repository returns to exactly the state the Merge started
/// from.
private struct MergeOperationActions: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        HStack {
            Button(.abortMerge, action: abort)
                .disabled(!state.canAbortMerge)
                .accessibilityIdentifier("repository.operation.abort")
            Button(.continueMerge, action: continueMerge)
                .buttonStyle(.borderedProminent)
                .disabled(!state.canContinueMerge)
                .help(
                    String(
                        localized: state.hasUnresolvedConflicts
                            ? .continueMergeBlockedHelp
                            : .continueMergeHelp
                    )
                )
                .accessibilityIdentifier("repository.operation.continue")
        }
    }

    private func abort() {
        Task {
            await state.abortMerge()
        }
    }

    private func continueMerge() {
        Task {
            await state.continueMerge()
        }
    }
}
