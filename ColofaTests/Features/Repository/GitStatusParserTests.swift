////
//  GitStatusParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct GitStatusParserTests {
    @Test
    func parsesBranchUpstreamPartialStagingRenameConflictAndUnusualPaths() throws {
        let output = [
            "# branch.oid 0123456789abcdef",
            "# branch.head feat/真实状态",
            "# branch.upstream origin/feat/真实状态",
            "# branch.ab +3 -2",
            "1 A. N... 000000 100644 100644 0000000 bbbbbbb Added.swift",
            "1 .D N... 100644 100644 000000 aaaaaaa bbbbbbb Deleted.swift",
            "1 .T N... 100644 100644 120000 aaaaaaa bbbbbbb Link",
            "1 MM N... 100644 100644 100644 aaaaaaa bbbbbbb Sources/My File.swift",
            "2 R. N... 100644 100644 100644 aaaaaaa bbbbbbb R100 Sources/新 名称.swift",
            "Sources/旧 名称.swift",
            "u UU N... 100644 100644 100644 100644 aaaaaaa bbbbbbb ccccccc 冲突 file.txt",
            "? Notes/emoji-🦄.md",
            "",
        ].joined(separator: "\0")

        let status = try GitStatusParser.parse(Data(output.utf8))

        #expect(status.head == .branch("feat/真实状态"))
        #expect(status.upstream == RepositoryUpstream(name: "origin/feat/真实状态", ahead: 3, behind: 2))
        #expect(status.stagedChanges == [
            RepositoryChange(path: "Added.swift", kind: .added),
            RepositoryChange(path: "Sources/My File.swift", kind: .modified),
            RepositoryChange(
                path: "Sources/新 名称.swift",
                kind: .renamed(from: "Sources/旧 名称.swift")
            ),
        ])
        #expect(status.unstagedChanges == [
            RepositoryChange(path: "冲突 file.txt", kind: .conflict),
            RepositoryChange(path: "Deleted.swift", kind: .deleted),
            RepositoryChange(path: "Link", kind: .typeChanged),
            RepositoryChange(path: "Notes/emoji-🦄.md", kind: .untracked),
            RepositoryChange(path: "Sources/My File.swift", kind: .modified),
        ])
    }

    /// Git stops counting once the ref it counted against is gone, and it says so by omitting
    /// `branch.ab` rather than by printing zeroes. Reading that silence as level would report a
    /// Branch as caught up with a remote-tracking Branch a Fetch Remotes just removed.
    @Test
    func readsAmissingAheadBehindAsAnUpstreamThatIsGone() throws {
        let output = [
            "# branch.oid 0123456789abcdef",
            "# branch.head feature",
            "# branch.upstream origin/feature",
            "",
        ].joined(separator: "\0")

        let status = try GitStatusParser.parse(Data(output.utf8))
        let upstream = try #require(status.upstream)

        #expect(upstream.name == "origin/feature")
        #expect(upstream.position == .gone)
        #expect(upstream.ahead == nil)
        #expect(upstream.behind == nil)
    }

    /// The other Branch Git declines to count is an Unborn one, and it is not gone: it simply has
    /// no Commit of its own to count from yet.
    @Test
    func readsAnUnbornBranchesUpstreamAsUnborn() throws {
        let output = [
            "# branch.oid (initial)",
            "# branch.head main",
            "# branch.upstream origin/main",
            "",
        ].joined(separator: "\0")

        let status = try GitStatusParser.parse(Data(output.utf8))
        let upstream = try #require(status.upstream)

        #expect(upstream.name == "origin/main")
        #expect(upstream.position == .unborn)
    }

    /// A counted upstream still reads as counted, including the level one a Fetch leaves behind.
    @Test
    func readsAcountedUpstreamAsItsCounts() throws {
        let output = [
            "# branch.oid 0123456789abcdef",
            "# branch.head main",
            "# branch.upstream origin/main",
            "# branch.ab +0 -0",
            "",
        ].joined(separator: "\0")

        let status = try GitStatusParser.parse(Data(output.utf8))

        #expect(status.upstream?.position == .counted(ahead: 0, behind: 0))
    }

    @Test
    func parsesUnbornAndDetachedHead() throws {
        let unborn = try GitStatusParser.parse(
            Data("# branch.oid (initial)\0# branch.head main\0".utf8)
        )
        let detached = try GitStatusParser.parse(
            Data("# branch.oid fedcba9876543210\0# branch.head (detached)\0".utf8)
        )

        #expect(unborn.head == .unbornBranch("main"))
        #expect(detached.head == .detached("fedcba9876543210"))
    }

    @Test
    func rejectsMalformedOutput() {
        #expect(throws: GitOutputParsingError.self) {
            try GitStatusParser.parse(Data("1 malformed\0".utf8))
        }
        #expect(throws: GitOutputParsingError.self) {
            try GitStatusParser.parse(
                Data(
                    "# branch.oid abc\0# branch.head main\0# branch.upstream origin/main\0# branch.ab nope\0".utf8
                )
            )
        }
    }
}
