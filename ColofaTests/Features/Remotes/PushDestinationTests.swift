////
//  PushDestinationTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// The address a Push writes to, and the one part of it that must never reach the screen.
struct PushDestinationTests {

    /// The address is shown so the user can check it, so everything that identifies the
    /// destination survives being displayed.
    @Test(arguments: [
        "ssh://git@example.invalid/Colofa.git",
        "https://example.invalid/Colofa.git",
        "git@example.invalid:anemoris/Colofa.git",
        "/Volumes/Backup/Colofa.git",
        "../Colofa.git",
        "file:///Volumes/Backup/Colofa.git",
    ])
    func anaddressWithNoPasswordIsShownExactlyAsGitReportedIt(url: String) {
        #expect(PushDestination(url).display == url)
    }

    /// A password stored in a remote URL is a secret Colofa was never asked to reveal, and the
    /// dialog is on screen for as long as the user takes to read it.
    @Test
    func apasswordIsReplacedRatherThanDisplayed() {
        let destination = PushDestination("https://user:s3cret@example.invalid/Colofa.git")

        #expect(!destination.display.contains("s3cret"))
        #expect(
            destination.display
                == "https://user:\(PushDestination.maskedPassword)@example.invalid/Colofa.git"
        )
    }

    /// The user name stays, because it says which account is writing — which is part of what the
    /// user is confirming — and Git shows it in its own messages for the same reason.
    @Test
    func theUserNameSurvivesThePassword() {
        let destination = PushDestination("https://someone@example.invalid:pw@example.invalid/x.git")

        #expect(destination.display.hasPrefix("https://someone@example.invalid:"))
        #expect(!destination.display.contains("pw@"))
    }

    /// A path can contain a colon and an `@`, and neither is a credential. Only the authority is
    /// examined, so nothing beyond the first slash can be mistaken for a secret.
    @Test
    func apathIsNeverMistakenForAcredential() {
        let url = "https://example.invalid/a:b@c/Colofa.git"

        #expect(PushDestination(url).display == url)
    }

    /// Two addresses are the same destination only when Git reported the same string, which is
    /// what the check before a Push compares.
    @Test
    func addressesCompareByWhatGitReported() {
        #expect(
            PushDestination("ssh://example.invalid/Colofa.git")
                == PushDestination("ssh://example.invalid/Colofa.git")
        )
        #expect(
            PushDestination("ssh://example.invalid/Colofa.git")
                != PushDestination("ssh://example.invalid/Mirror.git")
        )
    }
}
