////
//  StatusBarView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct StatusBarView: View {
    @Environment(WorkspaceState.self) private var state

    var body: some View {
        HStack {
            if let repository = state.repository {
                Label {
                    Text(verbatim: repository.rootURL.normalizedFilePath)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "folder")
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("repository.path")
            } else {
                Label {
                    Text(.noRepositoryOpen)
                } icon: {
                    Image(systemName: "arrow.triangle.branch")
                        .accessibilityHidden(true)
                }
            }

            Spacer()

            if let repository = state.repository {
                RepositoryHeadLabel(head: repository.head)
                if let upstream = repository.upstream {
                    Text(
                        verbatim: "→ \(upstream.name) · ↑\(upstream.ahead) ↓\(upstream.behind)"
                    )
                    .accessibilityLabel(Text(.upstream))
                    .accessibilityValue(Text(verbatim: upstreamAccessibilityValue(upstream)))
                    .accessibilityIdentifier("repository.upstream")
                }
                Label {
                    Text(repository.changeCount, format: .number)
                } icon: {
                    Image(systemName: "pencil.line")
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(Text(.changes))
                .accessibilityIdentifier("repository.changeCount")
            }

            if state.isLoadingRepository {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(Text(.loadingRepository))
            }
        }
        .foregroundStyle(.secondary)
        .font(.caption)
        .padding(.horizontal)
        .frame(height: 24)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func upstreamAccessibilityValue(_ upstream: RepositoryUpstream) -> String {
        "\(upstream.name), \(String(localized: .ahead)) \(upstream.ahead), "
            + "\(String(localized: .behind)) \(upstream.behind)"
    }
}
