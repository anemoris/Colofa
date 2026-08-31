////
//  SettingsGeneralView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// The one Settings pane: the language Colofa renders itself in, and what applying it takes.
///
/// Reached from the app menu rather than from the inspector, because the two states this control
/// matters most in — no Repository open, and Git missing entirely — are the two the inspector
/// does not exist in.
struct SettingsGeneralView: View {
    @Environment(WorkspaceState.self) private var state

    private let languageStore: AppLanguageStore
    private let relauncher: AppRelauncher
    private let languages: [DisplayLanguage]
    private let localizations: [String]

    /// The language the running process actually resolved at launch. Every "does this need a
    /// relaunch" question is asked against this rather than against the stored value, because it
    /// is what the window in front of the user is currently rendered in. Unlike the stored
    /// preferences it cannot go stale: a launch happened once.
    private let launchLanguage: String?

    @State private var preferences: DisplayLanguagePreferences
    @State private var didFailToRelaunch = false

    init(
        languageStore: AppLanguageStore,
        relauncher: AppRelauncher = .live(),
        bundle: Bundle = .main
    ) {
        self.languageStore = languageStore
        self.relauncher = relauncher
        self.localizations = bundle.localizations
        self.languages = DisplayLanguage.available(in: bundle.localizations)
        self.launchLanguage = bundle.preferredLocalizations.first
        _preferences = State(initialValue: DisplayLanguagePreferences(store: languageStore))
    }

    var body: some View {
        Form {
            Section {
                DisplayLanguagePicker(languages: languages, selection: selection)
            } header: {
                Text(.settingsGeneral)
            }

            if requiresRelaunch {
                Section {
                    LabeledContent {
                        Button(.relaunchNow, action: relaunch)
                            .disabled(!state.canReplaceRepository)
                            .help(Text(relaunchHelp))
                    } label: {
                        Text(.languageAppliesOnNextLaunch)
                    }

                    if didFailToRelaunch {
                        Text(.relaunchFailed)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settings.relaunchNotice")
            }
        }
        .formStyle(.grouped)
        .frame(width: LayoutMetrics.Settings.width)
        // `AppleLanguages` is shared with macOS's own per-app language row, so this window can be
        // looking at a choice the user has since changed in System Settings — and the user who
        // answers its restart prompt with "Later" comes straight back here. Nothing announces
        // that: a stored preference is not observable state, and `UserDefaults` posts no change
        // notification for a write another process made. So it is read again on the one event
        // that means the user has come back — Colofa becoming the active application.
        //
        // AppKit rather than `scenePhase`: a `Settings` scene is not a documented source of
        // phase transitions, and a trigger that quietly never fires would leave this pane stale
        // with nothing to show for it. This notification is the event itself rather than a proxy
        // for it, and the observation is one line that stays inside this view.
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            preferences = DisplayLanguagePreferences(store: languageStore)
        }
    }

    /// Written through rather than bound directly: only a choice the user made is stored. The
    /// refresh above assigns `preferences` on its own path, so re-reading what macOS decided can
    /// never be written back as though Colofa had decided it.
    private var selection: Binding<DisplayLanguageSelection> {
        Binding(
            get: { preferences.selection },
            set: { newSelection in
                preferences.selection = newSelection
                didFailToRelaunch = false
                languageStore.setSelection(newSelection)
            }
        )
    }

    private var requiresRelaunch: Bool {
        preferences.requiresRelaunch(
            fromLaunchLanguage: launchLanguage,
            availableLocalizations: localizations
        )
    }

    /// Quitting mid-Fetch is the failure this explains rather than merely prevents: the choice is
    /// already stored, so waiting costs the user nothing.
    private var relaunchHelp: LocalizedStringResource {
        state.canReplaceRepository ? .relaunchNowHelp : .relaunchUnavailableWhileBusy
    }

    private func relaunch() {
        Task {
            do {
                try await relauncher.relaunch()
            } catch {
                didFailToRelaunch = true
            }
        }
    }
}
