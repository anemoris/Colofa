////
//  DisplayLanguage.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One language Colofa can render its own interface in.
nonisolated struct DisplayLanguage: Hashable, Identifiable, Sendable {
    /// The bundle localization's own identifier, such as `zh-Hans`.
    let code: String

    var id: String { code }

    /// The language's name for itself. The user this picker exists for is the one who cannot read
    /// the language the rest of the window is in, so a row labelled in that language would be
    /// unreadable to exactly the person reaching for it. Apple labels its own language lists the
    /// same way.
    var endonym: String {
        Locale(identifier: code).localizedString(forIdentifier: code) ?? code
    }

    /// The languages the app actually ships, read from the bundle rather than listed here, so a
    /// localization added to the String Catalog appears without a code change.
    ///
    /// `Base` is a resource-loading fallback rather than a language anyone reads. The order is
    /// the code's, because a bundle reports its localizations in whatever order its resources
    /// happen to sit in and a picker whose rows move between launches cannot be used twice.
    static func available(in localizations: [String]) -> [Self] {
        localizations
            .filter { $0 != "Base" }
            .sorted()
            .map(Self.init(code:))
    }
}
