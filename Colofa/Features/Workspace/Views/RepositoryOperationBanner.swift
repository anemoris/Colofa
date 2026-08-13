////
//  RepositoryOperationBanner.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

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
            Spacer()
        }
        .padding()
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repository.operation")
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
