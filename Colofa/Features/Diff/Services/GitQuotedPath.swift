////
//  GitQuotedPath.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reverses the C-style quoting Git applies to a path in patch headers.
///
/// Colofa reads patches with `core.quotePath=false`, which stops Git escaping non-ASCII, but a
/// path holding a quote, a backslash, or a control character is still quoted. Escapes are decoded
/// as bytes rather than characters, because an octal escape names one byte of a multi-byte
/// character.
nonisolated enum GitQuotedPath {
    static func decoded(_ value: String) -> String {
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else {
            return value
        }
        let source = Array(value.utf8).dropFirst().dropLast()
        var bytes: [UInt8] = []
        var index = source.startIndex

        while index < source.endIndex {
            guard source[index] == UInt8(ascii: "\\"),
                  source.index(after: index) < source.endIndex else {
                bytes.append(source[index])
                index = source.index(after: index)
                continue
            }
            index = source.index(after: index)
            let escape = source[index]
            if let literal = literals[escape] {
                bytes.append(literal)
                index = source.index(after: index)
            } else if isOctalDigit(escape) {
                bytes.append(octal(from: source, startingAt: &index))
            } else {
                bytes.append(escape)
                index = source.index(after: index)
            }
        }

        return String(gitBytes: bytes)
    }

    /// The decoded leading quoted token and the text after it, used by the one header that states
    /// two paths on a single line.
    static func splitQuoted(_ value: String) -> (quoted: String, remainder: String)? {
        guard value.hasPrefix("\"") else {
            return nil
        }
        var isEscaped = false
        for index in value.indices.dropFirst() {
            if isEscaped {
                isEscaped = false
            } else if value[index] == "\\" {
                isEscaped = true
            } else if value[index] == "\"" {
                let after = value.index(after: index)
                return (
                    decoded(String(value[value.startIndex...index])),
                    String(value[after...].drop { $0 == " " })
                )
            }
        }
        return nil
    }

    private static let literals: [UInt8: UInt8] = [
        UInt8(ascii: "n"): 0x0A,
        UInt8(ascii: "t"): 0x09,
        UInt8(ascii: "r"): 0x0D,
        UInt8(ascii: "a"): 0x07,
        UInt8(ascii: "b"): 0x08,
        UInt8(ascii: "f"): 0x0C,
        UInt8(ascii: "v"): 0x0B,
    ]

    private static func isOctalDigit(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "7")).contains(byte)
    }

    /// Git writes exactly three octal digits, but a shorter run is still decoded rather than
    /// dropped, so malformed input costs no bytes.
    private static func octal(
        from source: ArraySlice<UInt8>,
        startingAt index: inout ArraySlice<UInt8>.Index
    ) -> UInt8 {
        var value = 0
        var digits = 0
        while digits < 3, index < source.endIndex, isOctalDigit(source[index]) {
            value = value * 8 + Int(source[index] - UInt8(ascii: "0"))
            index = source.index(after: index)
            digits += 1
        }
        return UInt8(truncatingIfNeeded: value)
    }
}
