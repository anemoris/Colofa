////
//  DisplayLanguagePicker.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

/// Chooses the Display Language: the system's own answer, or one of the languages Colofa ships.
struct DisplayLanguagePicker: View {
    let languages: [DisplayLanguage]
    @Binding var selection: DisplayLanguageSelection

    var body: some View {
        Picker(String(localized: .displayLanguage), selection: $selection) {
            Text(.followSystem)
                .tag(DisplayLanguageSelection.followSystem)

            Divider()

            ForEach(languages) { language in
                // Each row is a name in the language it names, so it is not read through the
                // language the user is trying to leave.
                Text(verbatim: language.endonym)
                    .tag(DisplayLanguageSelection.explicit(language.code))
            }
        }
        .accessibilityIdentifier("settings.displayLanguage")
    }
}
