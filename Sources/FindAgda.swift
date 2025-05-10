//
//  FindAgda.swift
//  macos-toolchain-finder
//
//  Created by Manuel M T Chakravarty on 08/05/2025.
//

import Foundation

private let whichPath              = URL(fileURLWithPath: "/usr/bin/which")
private let agdaName               = "agda"
private let agdaLanguageServerName = "als"
private let agdaVersionArg         = "--version"

/// Serach for tool configurations support Agda projects.
///
/// - Throws: If there is a fatal error preventing us from finding toolchains, the functions throws an error, which
///     might be a `FatalError`.
/// - Returns: Any Agda toolchain configurations found.
///
@MainActor
func findAgda() throws -> [ToolConfiguration] {

  let agdaPaths = try query(managerPath: whichPath, arguments: [agdaName], processLine: { $0 }),
      alsPaths  = try query(managerPath: whichPath, arguments: [agdaLanguageServerName], processLine: { $0 })

  if let agdaPath     = agdaPaths.map({ URL(filePath: $0) }).first,
     let alsPath      = alsPaths.map({ URL(filePath: $0) }).first,
     let (_, version) = try version(of: alsPath,
                                    arguments: [agdaVersionArg],
                                    matching: versionRegexpWithPrefix)
  {
    
    let configuration = ToolConfiguration(languageServerPath: alsPath,
                                          compilerPath: agdaPath,
                                          toolPath: agdaPath.deletingLastPathComponent(),
                                          version: String(version))
    return [configuration]

  } else { return [] }
}
