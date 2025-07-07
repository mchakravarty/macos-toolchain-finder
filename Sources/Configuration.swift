//
//  Configuration.swift
//  macos-toolchain-finder
//
//  Created by Manuel M T Chakravarty on 20/04/2025.
//

import Foundation


struct ToolConfiguration: Encodable, Equatable, Hashable {
  
  /// The path to the executable of the language server.
  ///
  let languageServerPath: URL
  
  /// The path of the executable of the matching compiler.
  ///
  let compilerPath: URL
  
  /// The (optional) path of matching package manager.
  /// 
  let packageManagerPath: URL?

  /// The path where tool executable reside, which should be part of the PATH when invoking the language server.
  ///
  let toolBinPath: URL
  
  /// The version of the language server.
  ///
  let version: String
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
