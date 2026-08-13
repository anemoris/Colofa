////
//  XCUIApplication+UITesting.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

extension XCUIApplication {
    /// UI tests run in English only, so the language and locale are fixed here rather than
    /// exposed as parameters.
    static func configuredForUITesting(
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ApplePersistenceIgnoreState", "YES",
            "-NSQuitAlwaysKeepsWindows", "NO",
            UITestingArgument.enabled,
        ] + additionalArguments
        return application
    }

    /// An application backed by the stubbed Repository service, restoring `path` on launch.
    static func configuredForRepository(
        path: String,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        configuredForUITesting(
            additionalArguments: [
                UITestingArgument.repositoryService,
                UITestingArgument.lastRepositoryPath, path,
            ] + additionalArguments
        )
    }

    /// A stubbed application whose restored Repository reports a fully populated Git state.
    static func configuredForRealRepositoryState(
        path: String,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        configuredForRepository(
            path: path,
            additionalArguments: [UITestingArgument.realRepositoryState] + additionalArguments
        )
    }
}
