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
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var state = state

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
                DetailView()
                    .navigationSplitViewColumnWidth(
                        min: LayoutMetrics.minimumDetailWidth,
                        ideal: LayoutMetrics.idealDetailWidth
                    )
            }
            .navigationTitle(state.repository?.name ?? String(localized: .appName))
            .inspector(isPresented: $state.isShowingInspector) {
                RepositoryInspector()
                    .inspectorColumnWidth(
                        min: LayoutMetrics.minimumInspectorWidth,
                        ideal: LayoutMetrics.idealInspectorWidth,
                        max: LayoutMetrics.maximumInspectorWidth
                    )
            }

            StatusBarView()
        }
    }
}
