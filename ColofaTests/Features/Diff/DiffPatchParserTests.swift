////
//  DiffPatchParserTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct DiffPatchParserTests {
    @Test
    func parsesHunksLineNumbersAndHeading() throws {
        let patch = """
        diff --git a/Sources/App.swift b/Sources/App.swift
        index 1111111..2222222 100644
        --- a/Sources/App.swift
        +++ b/Sources/App.swift
        @@ -12,5 +12,6 @@ func load() {
         context one
        -removed
        +added
        +also added
         context two
         context three

        """

        let files = try DiffPatchParser.parse(Data(patch.utf8))
        let file = try #require(files.first)
        let hunk = try #require(file.hunks.first)

        #expect(files.count == 1)
        #expect(file.oldPath == "Sources/App.swift")
        #expect(file.newPath == "Sources/App.swift")
        #expect(file.oldMode == "100644")
        #expect(file.isRenamed == false)
        #expect(hunk.heading == "func load() {")
        #expect(hunk.rangeDescription == "@@ -12,5 +12,6 @@")
        #expect(file.stats == DiffStats(additions: 2, deletions: 1))
        #expect(
            hunk.lines.map(\.kind)
                == [.context, .deletion, .addition, .addition, .context, .context]
        )
        #expect(hunk.lines.map(\.oldNumber) == [12, 13, nil, nil, 14, 15])
        #expect(hunk.lines.map(\.newNumber) == [12, nil, 13, 14, 15, 16])
        #expect(
            hunk.lines.map(\.text)
                == ["context one", "removed", "added", "also added", "context two", "context three"]
        )
    }

    @Test
    func parsesSeveralFilesAndSeveralHunks() throws {
        let patch = """
        diff --git a/one.txt b/one.txt
        index 1111111..2222222 100644
        --- a/one.txt
        +++ b/one.txt
        @@ -1 +1 @@
        -one
        +ONE
        @@ -10,2 +10,2 @@ tail
         kept
        -two
        +TWO
        diff --git a/two.txt b/two.txt
        new file mode 100644
        index 0000000..3333333
        --- /dev/null
        +++ b/two.txt
        @@ -0,0 +1,2 @@
        +first
        +second

        """

        let files = try DiffPatchParser.parse(Data(patch.utf8))

        #expect(files.count == 2)
        #expect(files[0].hunks.count == 2)
        // A range Git abbreviates to one number covers exactly one line.
        #expect(files[0].hunks[0].oldCount == 1)
        #expect(files[0].hunks[0].newCount == 1)
        #expect(files[0].hunks[1].heading == "tail")
        #expect(files[1].oldPath == nil)
        #expect(files[1].newPath == "two.txt")
        #expect(files[1].newMode == "100644")
        #expect(files[1].stats == DiffStats(additions: 2, deletions: 0))
    }

    @Test
    func dropsTheEmptyTimestampFieldGitAddsToAPathWithASpace() throws {
        let patch = """
        diff --git a/my file.txt b/my file.txt
        index 1111111..2222222 100644
        --- a/my file.txt\t
        +++ b/my file.txt\t
        @@ -1 +1 @@
        -old
        +new

        """

        let file = try #require(try DiffPatchParser.parse(Data(patch.utf8)).first)

        #expect(file.oldPath == "my file.txt")
        #expect(file.newPath == "my file.txt")
    }

    @Test
    func parsesRenameWithBothPaths() throws {
        let patch = """
        diff --git a/old name.txt b/new 名称.txt
        similarity index 82%
        rename from old name.txt
        rename to new 名称.txt
        index 3333333..4444444 100644
        --- a/old name.txt
        +++ b/new 名称.txt
        @@ -1,2 +1,2 @@
         kept
        -old
        +new

        """

        let file = try #require(try DiffPatchParser.parse(Data(patch.utf8)).first)

        #expect(file.oldPath == "old name.txt")
        #expect(file.newPath == "new 名称.txt")
        #expect(file.isRenamed)
        #expect(file.displayPath == "new 名称.txt")
    }

    @Test
    func parsesBinaryChangeWithoutFabricatingLines() throws {
        let patch = """
        diff --git a/image.png b/image.png
        index 5555555..6666666 100644
        Binary files a/image.png and b/image.png differ

        """

        let file = try #require(try DiffPatchParser.parse(Data(patch.utf8)).first)

        #expect(file.content == .binary)
        #expect(file.hunks.isEmpty)
        #expect(file.oldPath == "image.png")
        #expect(file.newPath == "image.png")
        #expect(file.stats == .zero)
    }

    @Test
    func parsesSubmoduleChangeAsBothCommitIDs() throws {
        let old = String(repeating: "a", count: 40)
        let new = String(repeating: "b", count: 40)
        let patch = """
        diff --git a/vendor/module b/vendor/module
        index \(old)..\(new) 160000
        --- a/vendor/module
        +++ b/vendor/module
        @@ -1 +1 @@
        -Subproject commit \(old)
        +Subproject commit \(new)

        """

        let file = try #require(try DiffPatchParser.parse(Data(patch.utf8)).first)

        #expect(file.content == .submodule(oldCommitID: old, newCommitID: new))
    }

    @Test
    func parsesAddedSubmoduleWithOnlyItsNewCommitID() throws {
        let new = String(repeating: "c", count: 40)
        let patch = """
        diff --git a/vendor/added b/vendor/added
        new file mode 160000
        index 0000000..\(new)
        --- /dev/null
        +++ b/vendor/added
        @@ -0,0 +1 @@
        +Subproject commit \(new)

        """

        let file = try #require(try DiffPatchParser.parse(Data(patch.utf8)).first)

        #expect(file.content == .submodule(oldCommitID: nil, newCommitID: new))
    }

    @Test
    func parsesNoNewlineMarkerAsItsOwnLine() throws {
        let patch = """
        diff --git a/tail.txt b/tail.txt
        index 1111111..2222222 100644
        --- a/tail.txt
        +++ b/tail.txt
        @@ -1 +1 @@
        -old
        \\ No newline at end of file
        +new

        """

        let hunk = try #require(try DiffPatchParser.parse(Data(patch.utf8)).first?.hunks.first)

        #expect(hunk.lines.map(\.kind) == [.deletion, .noNewlineMarker, .addition])
        #expect(hunk.stats == DiffStats(additions: 1, deletions: 1))
    }

    @Test
    func parsesModeOnlyChangeFromTheHeaderThatStatesBothPaths() throws {
        let patch = """
        diff --git a/script sh b/script sh
        old mode 100644
        new mode 100755

        """

        let file = try #require(try DiffPatchParser.parse(Data(patch.utf8)).first)

        #expect(file.oldPath == "script sh")
        #expect(file.newPath == "script sh")
        #expect(file.changedMode?.old == "100644")
        #expect(file.changedMode?.new == "100755")
        #expect(file.content == .text([]))
    }

    @Test
    func decodesAQuotedPathInTheHeaderThatStatesBothPaths() throws {
        let patch = """
        diff --git "a/od\\td.bin" "b/od\\td.bin"
        index 1111111..2222222 100644
        Binary files "a/od\\td.bin" and "b/od\\td.bin" differ

        """

        let file = try #require(try DiffPatchParser.parse(Data(patch.utf8)).first)

        #expect(file.newPath == "od\td.bin")
        #expect(file.content == .binary)
    }

    @Test
    func readsAPatchWhoseBytesAreNotUTF8() throws {
        var data = Data(
            """
            diff --git a/latin.txt b/latin.txt
            index 1111111..2222222 100644
            --- a/latin.txt
            +++ b/latin.txt
            @@ -1 +1 @@
            -old
            +
            """.utf8
        )
        // A lone 0xE9 is Latin-1 "é" and is not valid UTF-8.
        data.append(contentsOf: [0xE9, UInt8(ascii: "\n")])

        let hunk = try #require(try DiffPatchParser.parse(data).first?.hunks.first)

        #expect(hunk.lines.last?.text == "é")
    }

    @Test
    func refusesOutputThatIsNotAPatch() {
        #expect(throws: GitOutputParsingError.self) {
            try DiffPatchParser.parse(Data("fatal: not a patch\n".utf8))
        }
        #expect(throws: GitOutputParsingError.self) {
            try DiffPatchParser.parse(Data("diff --cc conflict.txt\n".utf8))
        }
    }

    @Test
    func refusesACombinedDiffRatherThanReadingItAsTwoSided() {
        let patch = """
        diff --git a/conflict.txt b/conflict.txt
        index 1111111,2222222..0000000
        @@@ -1,2 -1,2 +1,3 @@@
        ++ours

        """

        #expect(throws: GitOutputParsingError.self) {
            try DiffPatchParser.parse(Data(patch.utf8))
        }
    }

    @Test
    func readsAnEmptyPatchAsNoFiles() throws {
        #expect(try DiffPatchParser.parse(Data()).isEmpty)
    }
}
