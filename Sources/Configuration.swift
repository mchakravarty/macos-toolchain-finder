//
//  Configuration.swift
//  macos-toolchain-finder
//
//  Created by Manuel M T Chakravarty on 20/04/2025.
//

import Foundation


struct ToolConfiguration: Encodable, Equatable, Hashable {
  let languageServerPath: URL
  let compilerPath:       URL
  let version:            String
}

enum FatalError: Error {
  case couldNotRun(commandName: String)
  case couldNotConvertToJSON
}

extension FatalError: LocalizedError {

  var errorDescription: String? {

    switch self {
    case .couldNotRun(commandName: let commandName):
      "Could not run '\(commandName)'"
    case .couldNotConvertToJSON:
      "Interal error: could not convert output to JSON"
    }
  }
}
