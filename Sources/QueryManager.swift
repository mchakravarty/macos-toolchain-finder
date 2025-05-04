//
//  QueryManager.swift
//  macos-toolchain-finder
//
//  Created by Manuel M T Chakravarty on 01/05/2025.
//

import Foundation


/// Query a installation manager tool and post process its output.
///
/// - Parameters:
///   - managerPath: Path to the executable of the manager tool.
///   - arguments: Arguments for the manager tool.
///   - processLine: Function to post process individual lines of the Output of the tool.
/// - Throws: Throws fatal errors.
/// - Returns: Returns a list of query results per line of the manager tool (that wasn't filtered out by `processLine`.)
///
func query<LineResult>(managerPath: URL, arguments: [String], processLine: (String) throws -> LineResult?)
throws -> [LineResult]
{

  let process = Process(),
      output  = Pipe()
  process.executableURL  = managerPath
  process.arguments      = arguments
  process.standardOutput = output
  try process.run()

  if let data   = try output.fileHandleForReading.readToEnd(),
     let string = String(data: data, encoding: .utf8)
  {
    process.waitUntilExit()
    return try string
      .components(separatedBy: "\n")
      .compactMap(processLine)

  } else {
    process.waitUntilExit()
    return []
  }
}
