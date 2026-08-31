////
//  AppRelauncher.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import AppKit

/// Starts a second copy of Colofa and quits this one, so a Display Language change is read at
/// launch the way AppKit's own menus and panels read it.
///
/// The only type in the app that touches `NSWorkspace` or `NSApplication`: SwiftUI has no
/// equivalent for relaunching a bundle, so the AppKit use stays behind one value with one
/// closure. Opening the app's own bundle is available because Colofa is unsandboxed (ADR-0002).
nonisolated struct AppRelauncher: Sendable {
    /// Throws when the replacement could not be started, which is the one case where quitting
    /// would leave the user with no app at all.
    let relaunch: @MainActor @Sendable () async throws -> Void

    static func live(bundle: Bundle = .main) -> Self {
        Self {
            let configuration = NSWorkspace.OpenConfiguration()
            // Without this the running instance is activated instead of a new one being started,
            // and nothing would ever re-read the language.
            configuration.createsNewApplicationInstance = true

            // The replacement has to be running before this one goes away: terminating first
            // would race macOS's own "the app quit" bookkeeping against the new launch.
            _ = try await NSWorkspace.shared.openApplication(
                at: bundle.bundleURL,
                configuration: configuration
            )
            NSApplication.shared.terminate(nil)
        }
    }
}
