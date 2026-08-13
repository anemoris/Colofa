////
//  GitObjectSizeParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct GitObjectSizeParser {
    nonisolated static func parse(_ output: String) throws -> Int64 {
        var looseSize: Int64?
        var packedSize: Int64?

        for line in output.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 1)
            guard fields.count == 2 else { continue }

            switch fields[0] {
            case "size:":
                looseSize = Int64(fields[1])
            case "size-pack:":
                packedSize = Int64(fields[1])
            default:
                continue
            }
        }

        guard let looseSize, let packedSize, looseSize >= 0, packedSize >= 0 else {
            throw GitOutputParsingError()
        }
        let (kilobytes, additionOverflowed) = looseSize.addingReportingOverflow(packedSize)
        let (bytes, multiplicationOverflowed) = kilobytes.multipliedReportingOverflow(by: 1_024)
        guard !additionOverflowed, !multiplicationOverflowed else {
            throw GitOutputParsingError()
        }
        return bytes
    }
}
