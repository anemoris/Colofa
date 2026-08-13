////
//  ColofaApp.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

@main
struct ColofaApp: App {
    @State private var state: WorkspaceState

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let service: RepositoryService
#if DEBUG
        if arguments.contains(UITestingArgument.gitUnavailable) {
            service = .unavailable()
        } else if arguments.contains(UITestingArgument.repositoryService) {
            service = .uiTesting(arguments: arguments)
        } else {
            service = .live()
        }
#else
        service = .live()
#endif
        _state = State(
            initialValue: WorkspaceState(
                repositoryService: service,
                launchArguments: arguments
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceRootView()
                .environment(state)
                .frame(
                    minWidth: LayoutMetrics.minimumWindowWidth,
                    minHeight: LayoutMetrics.minimumWindowHeight
                )
        }
        .defaultSize(
            width: LayoutMetrics.defaultWindowWidth,
            height: LayoutMetrics.defaultWindowHeight
        )
        .windowToolbarStyle(.unified)
        .commands {
            ColofaCommands(state: state)
        }
    }
}
