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
                    Text(verbatim: repository.rootURL.homeRelativeFilePath())
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
                    UpstreamLabel(upstream: upstream)
                }
                Label {
                    Text(repository.changeCount, format: .number)
                } icon: {
                    Image(systemName: "pencil.line")
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(Text(.changes))
                .accessibilityIdentifier("repository.changeCount")

                LastFetchLabel(date: state.lastFetchDate)
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
}

/// The upstream the current Branch tracks, and how far it stands from it.
///
/// A Branch whose upstream ref is gone shows that it is gone rather than showing counts: Git
/// stops counting once the ref it counted against is no longer there, and printing `↑0 ↓0`
/// instead would tell the user the Branch is caught up with something that does not exist. The
/// word carries it rather than a color, so the state survives Differentiate Without Color.
private struct UpstreamLabel: View {
    let upstream: RepositoryUpstream

    var body: some View {
        Text(verbatim: "→ \(upstream.name)\(counts)")
            .accessibilityLabel(Text(.upstream))
            .accessibilityValue(Text(verbatim: accessibilityValue))
            .accessibilityIdentifier("repository.upstream")
    }

    /// What follows the upstream's name, which is nothing at all for an Unborn Branch: it has no
    /// Commit to count from, and that is not a state worth naming in the status bar.
    private var counts: String {
        switch upstream.position {
        case .counted(let ahead, let behind):
            " · ↑\(ahead) ↓\(behind)"
        case .gone:
            " · \(String(localized: .upstreamGone))"
        case .unborn:
            ""
        }
    }

    private var accessibilityValue: String {
        switch upstream.position {
        case .counted(let ahead, let behind):
            "\(upstream.name), \(String(localized: .ahead)) \(ahead), "
                + "\(String(localized: .behind)) \(behind)"
        case .gone:
            "\(upstream.name), \(String(localized: .upstreamGone))"
        case .unborn:
            upstream.name
        }
    }
}

/// When Colofa last fetched this Repository.
///
/// App-owned metadata rather than something Git records, so it says nothing about work another
/// client did — and a Repository Colofa has never fetched says exactly that rather than borrowing
/// a time from somewhere else.
private struct LastFetchLabel: View {
    let date: Date?

    var body: some View {
        Label {
            if let date {
                Text(date, format: .relative(presentation: .named))
            } else {
                Text(.lastFetchNever)
            }
        } icon: {
            Image(systemName: "clock.arrow.circlepath")
                .accessibilityHidden(true)
        }
        .accessibilityLabel(Text(.lastFetch))
        .accessibilityValue(Text(verbatim: accessibilityValue))
        .accessibilityIdentifier("repository.lastFetch")
    }

    private var accessibilityValue: String {
        guard let date else {
            return String(localized: .lastFetchNever)
        }
        return date.formatted(.relative(presentation: .named))
    }
}
