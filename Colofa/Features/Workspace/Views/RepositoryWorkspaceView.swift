////
//  RepositoryWorkspaceView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryWorkspaceView: View {
    @Environment(WorkspaceState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        VStack(spacing: 0) {
            if let details = state.repositoryFailureDetails {
                RepositoryFailureBanner(
                    details: details,
                    message: state.repositoryFailureMessage ?? .gitCommandFailedDescription
                )
            }

            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView()
                    .navigationSplitViewColumnWidth(
                        min: LayoutMetrics.minimumSidebarWidth,
                        ideal: LayoutMetrics.idealSidebarWidth,
                        max: LayoutMetrics.maximumSidebarWidth
                    )
            } content: {
                WorkspaceContentView(section: state.selectedSection)
                    .navigationSplitViewColumnWidth(
                        min: LayoutMetrics.minimumContentWidth,
                        ideal: LayoutMetrics.idealContentWidth,
                        max: LayoutMetrics.maximumContentWidth
                    )
            } detail: {
                // Repository Info is a plain panel beside the detail view rather than the system
                // `.inspector()`, which is a split view of its own. Outside the detail column it
                // counted its width twice and pushed the sidebar and itself past both edges of the
                // window; inside it, opening it widened the window by its own width every time.
                // A plain panel is laid out by SwiftUI alone: opening it only narrows the detail
                // view, and the window keeps its size.
                HStack(spacing: 0) {
                    DetailView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if state.isShowingInspector {
                        Divider()
                        RepositoryInspector()
                            .frame(width: LayoutMetrics.inspectorWidth)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .background(.windowBackground)
                            .transition(.move(edge: .trailing))
                    }
                }
                .clipped()
                .animation(reduceMotion ? nil : .default, value: state.isShowingInspector)
                .navigationSplitViewColumnWidth(
                    min: LayoutMetrics.minimumDetailWidth,
                    ideal: LayoutMetrics.idealDetailWidth
                )
            }
            .navigationTitle(state.repository?.name ?? String(localized: .appName))

            StatusBarView()
        }
    }
}
