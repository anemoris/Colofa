////
//  PushDestinationRefusalTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a refused destination actually says, read in the language these assertions are written in
/// rather than in whatever language the machine running them is set to.
///
/// The wording is checked because a refusal has to name the configuration it is about: the user
/// has to be able to find it in Git afterwards, and a message whose arguments did not reach it
/// would say nothing they could act on.
struct PushDestinationRefusalTests {
    private func english(_ refusal: PushDestinationRefusal) -> String {
        var message = refusal.message
        message.locale = Locale(identifier: "en")
        return String(localized: message)
    }

    @Test
    func therefusedRemoteIsNamed() {
        #expect(english(.localRepository(remote: ".")).contains("“.”"))
        #expect(english(.changed(remote: "origin")).contains("“origin”"))
    }

    /// Both arguments, which is the one thing a positional format specifier can get wrong without
    /// failing to compile: the remote's name and every address one Push would have written to.
    @Test
    func severalDestinationsNamesTheRemoteAndEveryAddress() {
        let message = english(.severalDestinations(
            remote: "origin",
            [
                PushDestination("ssh://example.invalid/Colofa.git"),
                PushDestination("ssh://example.invalid/Mirror.git"),
            ]
        ))

        #expect(message.contains("“origin”"))
        #expect(message.contains("ssh://example.invalid/Colofa.git"))
        #expect(message.contains("ssh://example.invalid/Mirror.git"))
    }

    /// The addresses are listed the way they are displayed, so a password stored in a remote URL
    /// does not reach the screen by way of the refusal that mentions it.
    @Test
    func alistedAddressCarriesNopassword() {
        let message = english(.severalDestinations(
            remote: "origin",
            [
                PushDestination("https://user:s3cret@example.invalid/Colofa.git"),
                PushDestination("ssh://example.invalid/Mirror.git"),
            ]
        ))

        #expect(!message.contains("s3cret"))
        #expect(message.contains(PushDestination.maskedPassword))
    }

    /// Each refusal is its own answer, because the user does something different about each.
    @Test
    func eachRefusalHasItsOwnTitle() {
        let titles = [
            PushDestinationRefusal.localRepository(remote: "."),
            .severalDestinations(remote: "origin", []),
            .changed(remote: "origin"),
        ].map { refusal -> String in
            var title = refusal.title
            title.locale = Locale(identifier: "en")
            return String(localized: title)
        }

        #expect(Set(titles).count == titles.count)
    }
}
