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
    private let languageStore: AppLanguageStore

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
        languageStore = Self.languageStore()
    }

    /// The app's own preferences domain, except under a UI test that has asked for a throwaway
    /// suite: choosing a language writes `AppleLanguages`, and a test must never leave that on
    /// the machine running it.
    private static func languageStore() -> AppLanguageStore {
#if DEBUG
        if let suiteName = UserDefaults.standard.string(
            forKey: String(UITestingArgument.settingsDefaultsSuite.dropFirst())
        ),
            let defaults = UserDefaults(suiteName: suiteName) {
            return AppLanguageStore(userDefaults: defaults, domainName: suiteName)
        }
#endif
        return .live()
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

        // SwiftUI mounts the app menu's Settings item and its Command-comma shortcut on its own,
        // which is why ColofaCommands says nothing about either. It is a separate window, so it
        // is reachable with no Repository open and while Git itself is missing — the two states
        // a user who cannot read the interface is most likely to be stuck in.
        Settings {
            SettingsGeneralView(languageStore: languageStore)
                .environment(state)
        }
    }
}
