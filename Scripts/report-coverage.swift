#!/usr/bin/env swift

import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: Scripts/report-coverage.swift <result.xcresult>\n".utf8))
    exit(EXIT_FAILURE)
}

func reportError(_ description: String) -> NSError {
    NSError(
        domain: "ColofaCoverageReport",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: description]
    )
}

let process = Process()
let output = Pipe()
process.executableURL = URL(filePath: "/usr/bin/xcrun")
process.arguments = ["xccov", "view", "--report", "--json", CommandLine.arguments[1]]
process.standardOutput = output

do {
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == EXIT_SUCCESS else {
        throw reportError("xccov exited with status \(process.terminationStatus).")
    }

    let decodedReport: Any
    do {
        decodedReport = try JSONSerialization.jsonObject(with: data)
    } catch {
        throw reportError("xccov returned invalid JSON: \(error.localizedDescription)")
    }

    guard let report = decodedReport as? [String: Any],
          let targets = report["targets"] as? [[String: Any]] else {
        throw reportError("xccov report does not contain a targets array.")
    }

    guard let target = targets.first(where: { $0["name"] as? String == "Colofa.app" }) else {
        throw reportError("xccov report does not contain the Colofa.app target.")
    }

    guard let files = target["files"] as? [[String: Any]] else {
        throw reportError("Colofa.app coverage does not contain a files array.")
    }

    var swiftUICovered = 0
    var swiftUIExecutable = 0
    var logicCovered = 0
    var logicExecutable = 0

    for file in files {
        guard let path = file["path"] as? String,
              let covered = file["coveredLines"] as? Int,
              let executable = file["executableLines"] as? Int else {
            throw reportError("A Colofa.app coverage entry is missing its path or line counts.")
        }

        let source: String
        do {
            source = try String(contentsOf: URL(filePath: path), encoding: .utf8)
        } catch {
            throw reportError("Could not read coverage source \(path): \(error.localizedDescription)")
        }

        if source.contains("import SwiftUI") {
            swiftUICovered += covered
            swiftUIExecutable += executable
        } else {
            logicCovered += covered
            logicExecutable += executable
        }
    }

    func printCoverage(_ name: String, covered: Int, executable: Int) {
        let ratio = executable == 0 ? 0 : Double(covered) / Double(executable)
        print("\(name): \(covered)/\(executable) (\(ratio.formatted(.percent.precision(.fractionLength(1)))))")
    }

    printCoverage("SwiftUI declarations", covered: swiftUICovered, executable: swiftUIExecutable)
    printCoverage("Non-SwiftUI logic", covered: logicCovered, executable: logicExecutable)
} catch {
    FileHandle.standardError.write(Data("Coverage report failed: \(error.localizedDescription)\n".utf8))
    exit(EXIT_FAILURE)
}
