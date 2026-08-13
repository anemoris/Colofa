////
//  RepositoryHeadLabel.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryHeadLabel: View {
    let head: RepositoryHead
    var showsCurrentBranchIndicator = false

    var body: some View {
        switch head {
        case .branch(let name):
            Label {
                Text(verbatim: name)
            } icon: {
                Image(
                    systemName: showsCurrentBranchIndicator
                        ? "checkmark"
                        : "arrow.triangle.branch"
                )
            }
                .accessibilityLabel(Text(.currentBranch))
                .accessibilityValue(Text(verbatim: name))
        case .unbornBranch(let name):
            VStack(alignment: .leading) {
                Label {
                    Text(verbatim: name)
                } icon: {
                    Image(systemName: "arrow.triangle.branch")
                }
                Text(.unbornBranch)
                    .foregroundStyle(.secondary)
            }
        case .detached(let commit):
            VStack(alignment: .leading) {
                Label(.detachedHead, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Text(verbatim: String(commit.prefix(12)))
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
