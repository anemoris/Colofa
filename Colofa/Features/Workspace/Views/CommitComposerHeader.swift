////
//  CommitComposerHeader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import SwiftUI

/// What the next Commit will land on and how much it will contain.
struct CommitComposerHeader: View {
    let repository: RepositorySnapshot

    var body: some View {
        HStack {
            RepositoryHeadLabel(head: repository.head)
                .accessibilityIdentifier("repository.commit.branch")

            Spacer()

            LabeledContent(String(localized: .commitStagedFiles)) {
                Text(repository.stagedChanges.count, format: .number)
                    .accessibilityIdentifier("repository.commit.stagedCount")
            }
            .fixedSize()
        }
        .font(.callout)
    }
}
