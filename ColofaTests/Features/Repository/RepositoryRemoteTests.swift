////
//  RepositoryRemoteTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// What a remote address may carry, and what the Inspector is allowed to put on screen.
struct RepositoryRemoteTests {

    /// The Inspector row is selectable and copyable, and it stays on screen for as long as the
    /// user leaves the Inspector open — including through a screen share. A token stored in the
    /// remote URL must not be part of any of that.
    @Test
    func apasswordInAremoteUrlIsNeverDisplayed() {
        let remote = RepositoryRemote(
            name: "origin",
            url: "https://user:s3cret@example.invalid/Colofa.git"
        )

        #expect(!remote.displayURL.contains("s3cret"))
        #expect(
            remote.displayURL
                == "https://user:\(PushDestination.maskedPassword)@example.invalid/Colofa.git"
        )
    }

    /// The address is shown so the user can tell one remote from another, so masking may not
    /// touch an address that carries no secret at all.
    @Test(arguments: [
        "ssh://git@example.invalid/Colofa.git",
        "https://example.invalid/Colofa.git",
        "https://user@example.invalid/Colofa.git",
        "git@example.invalid:anemoris/Colofa.git",
        "/Volumes/Backup/Colofa.git",
    ])
    func anaddressWithNoPasswordIsShownAsGitReportedIt(url: String) {
        #expect(RepositoryRemote(name: "origin", url: url).displayURL == url)
    }

    /// The unmasked address stays available, because a Fetch or a Push has to be given the real
    /// one. Masking is a display rule, not a rewrite of the configuration.
    @Test
    func theStoredAddressKeepsItsCredentialForGitItself() {
        let url = "https://user:s3cret@example.invalid/Colofa.git"

        #expect(RepositoryRemote(name: "origin", url: url).url == url)
    }
}
