//
//  TestTool.swift
//  macos-toolchain-finder
//
//  Created by Manuel M T Chakravarty on 21/04/2025.
//

import Foundation
import RegexBuilder


@MainActor
let versionRegexp = Regex {
  One(.digit)
  OneOrMore {
    ChoiceOf {
      .digit
      "."
    }
  }
}

@MainActor
let versionRegexpWithPrefix = Regex {
  ZeroOrMore {
    ChoiceOf {
      One(.word)
      One(.horizontalWhitespace)
    }
  }
  Capture { versionRegexp }
}

/// Run the given tool with the given arguments and match the output with the given regex to obtain the tool version.
///
/// - Parameters:
///   - toolPath: The path of the tool to run.
///   - arguments: The arguments to pass for the tool to print its version.
///   - matching: The regex to match the output for the version.
/// - Throws: Throws fatal errors.
/// - Returns: Returns the matched version or `nil` if matching was not successful.
///
func version(of toolPath: URL, arguments: [String], matching: Regex<(Substring, Substring)>) throws -> String? {

  let process = Process(),
      output  = Pipe()
  process.executableURL  = toolPath
  process.arguments      = arguments
  process.standardOutput = output
  try process.run()
  process.waitUntilExit()

  if let data    = try output.fileHandleForReading.readToEnd(),
     let string  = String(data: data, encoding: .utf8),
     let version = try matching.firstMatch(in: string)?.output.1
  {
    return String(version)
  } else {
    return nil
  }
}
