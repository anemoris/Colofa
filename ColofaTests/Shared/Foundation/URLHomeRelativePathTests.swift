////
//  URLHomeRelativePathTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

/// Every case pins `home` rather than reading the machine's own, so the suite asserts the rule
/// instead of the developer account it happens to run under.
struct URLHomeRelativePathTests {
    private let home = "/Users/mia"

    @Test
    func pathInsideHomeBecomesHomeRelative() {
        let url = URL(filePath: "/Users/mia/Developer/Colofa", directoryHint: .isDirectory)
        #expect(url.homeRelativeFilePath(home: home) == "~/Developer/Colofa")
    }

    @Test
    func homeItselfBecomesTilde() {
        let url = URL(filePath: "/Users/mia", directoryHint: .isDirectory)
        #expect(url.homeRelativeFilePath(home: home) == "~")
    }

    /// The case a naive prefix check gets wrong: the sibling shares every character of the home
    /// path and is not inside it, so abbreviating it would rename someone else's directory.
    @Test
    func siblingSharingThePrefixKeepsItsAbsolutePath() {
        let url = URL(filePath: "/Users/mia-archive/Colofa", directoryHint: .isDirectory)
        #expect(url.homeRelativeFilePath(home: home) == "/Users/mia-archive/Colofa")
    }

    @Test
    func pathOutsideHomeKeepsItsAbsolutePath() {
        let url = URL(filePath: "/tmp/Colofa", directoryHint: .isDirectory)
        #expect(url.homeRelativeFilePath(home: home) == "/tmp/Colofa")
    }

    @Test
    func trailingSlashOnHomeIsIgnored() {
        let url = URL(filePath: "/Users/mia/Colofa", directoryHint: .isDirectory)
        #expect(url.homeRelativeFilePath(home: "/Users/mia/") == "~/Colofa")
    }

    /// A home of `/` or of nothing would abbreviate the whole volume, which carries no
    /// information. Both leave the path alone.
    @Test(arguments: ["", "/"])
    func degenerateHomeLeavesThePathAlone(home: String) {
        let url = URL(filePath: "/Users/mia/Colofa", directoryHint: .isDirectory)
        #expect(url.homeRelativeFilePath(home: home) == "/Users/mia/Colofa")
    }

    /// The trailing slash a directory URL carries is dropped before the comparison, so a
    /// Repository root abbreviates the same way whether or not it was built as a directory.
    @Test
    func directoryURLDropsItsTrailingSlash() {
        let url = URL(filePath: "/Users/mia/Developer/Colofa/", directoryHint: .isDirectory)
        #expect(url.homeRelativeFilePath(home: home) == "~/Developer/Colofa")
    }
}
