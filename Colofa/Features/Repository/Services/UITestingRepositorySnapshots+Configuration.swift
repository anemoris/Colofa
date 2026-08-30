////
//  UITestingRepositorySnapshots+Configuration.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The Git configuration every stubbed Repository reports, which is one fixture rather than one
/// per Repository state: the scopes and the shadowed value are what the configuration pane is
/// about, and they are the same whichever workflow a UI test came to drive.
///
/// Declared `nonisolated` for the same reason the rest of the fixture is: the project defaults to
/// Main Actor isolation while `UITestingRepositoryService` builds these from an actor.
nonisolated extension UITestingRepositorySnapshots {
    /// Not private: the Pull and Push fixtures in UITestingRepositorySnapshots+Pull.swift and
    /// UITestingRepositorySnapshots+Push.swift build on the same Repository configuration, and
    /// Swift keeps `private` within one file.
    static func configuration(at url: URL) -> GitConfigurationSnapshot {
        GitConfigurationSnapshot(
            entries: [
                GitConfigurationEntry(
                    key: .httpProxy,
                    value: "http://system.example.invalid:8080",
                    scope: .system,
                    origin: GitConfigurationOrigin(rawValue: "file:/etc/gitconfig")
                ),
                GitConfigurationEntry(
                    key: .userName,
                    value: "Colofa UI Author",
                    scope: .global,
                    origin: GitConfigurationOrigin(rawValue: "file:/tmp/colofa-ui-global.gitconfig")
                ),
                GitConfigurationEntry(
                    key: .userEmail,
                    value: "global@example.invalid",
                    scope: .global,
                    origin: GitConfigurationOrigin(rawValue: "file:/tmp/colofa-ui-global.gitconfig")
                ),
                GitConfigurationEntry(
                    key: .userEmail,
                    value: "local@example.invalid",
                    scope: .local,
                    origin: GitConfigurationOrigin(
                        rawValue: "file:\(url.appending(path: ".git").normalizedFilePath)/config"
                    )
                ),
            ]
        )
    }
}
#endif
