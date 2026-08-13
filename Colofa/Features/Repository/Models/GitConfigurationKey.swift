////
//  GitConfigurationKey.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

nonisolated enum GitConfigurationKey: String, CaseIterable, Hashable, Identifiable, Sendable {
    case userName = "user.name"
    case userEmail = "user.email"
    case httpProxy = "http.proxy"

    var id: Self { self }

    static var gitReadPattern: String {
        let keys = allCases.map { NSRegularExpression.escapedPattern(for: $0.rawValue) }
        return "^(\(keys.joined(separator: "|")))$"
    }

    var title: LocalizedStringResource {
        switch self {
        case .userName:
            .configurationUserName
        case .userEmail:
            .configurationUserEmail
        case .httpProxy:
            .configurationHTTPProxy
        }
    }

    /// The explanatory line shown under the field. Named `helpText` rather than `description`
    /// so it is not mistaken for `CustomStringConvertible`.
    var helpText: LocalizedStringResource {
        switch self {
        case .userName:
            .configurationUserNameDescription
        case .userEmail:
            .configurationUserEmailDescription
        case .httpProxy:
            .configurationHTTPProxyDescription
        }
    }

    var validationWarning: LocalizedStringResource? {
        switch self {
        case .userEmail:
            .configurationEmailWarning
        case .userName, .httpProxy:
            nil
        }
    }

    func warning(for value: String) -> LocalizedStringResource? {
        guard !value.isEmpty else {
            return nil
        }

        switch self {
        case .userEmail where !value.contains("@"):
            return validationWarning
        case .userName, .userEmail, .httpProxy:
            return nil
        }
    }
}
