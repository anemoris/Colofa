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

    /// A stubbed application whose restored Repository has Refs to check out and nothing
    /// standing in the way of one.
    static func configuredForBranchState(
        path: String,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        configuredForRepository(
            path: path,
            additionalArguments: [UITestingArgument.branchState] + additionalArguments
        )
    }

    /// A stubbed application whose restored Repository has a Branch worth merging into the
    /// current one, and a working tree holding only what the test asked for.
    static func configuredForMergeState(
        path: String,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        configuredForRepository(
            path: path,
            additionalArguments: [UITestingArgument.mergeState] + additionalArguments
        )
    }

    /// A stubbed application whose restored Repository has remotes worth fetching.
    static func configuredForFetchState(
        path: String,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        configuredForRepository(
            path: path,
            additionalArguments: [UITestingArgument.fetchState] + additionalArguments
        )
    }

    /// A stubbed application whose restored Repository has a current Branch behind its upstream.
    static func configuredForPullState(
        path: String,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        configuredForRepository(
            path: path,
            additionalArguments: [UITestingArgument.pullState] + additionalArguments
        )
    }

    /// A stubbed application whose restored Repository has a current Branch ahead of its upstream.
    static func configuredForPushState(
        path: String,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        configuredForRepository(
            path: path,
            additionalArguments: [UITestingArgument.pushState] + additionalArguments
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
