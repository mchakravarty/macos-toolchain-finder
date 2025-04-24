//
//  FindSwift.swift
//  macos-toolchain-finder
//
//  Created by Manuel M T Chakravarty on 20/04/2025.
//

import Foundation


private let xcodeSelectPath  = URL(fileURLWithPath: "/usr/bin/xcode-select")
private let sourcekitLspPath = URL(fileURLWithPath: "/usr/bin/sourcekit-lsp")
private let swiftcPath       = URL(fileURLWithPath: "/usr/bin/swiftc")
private let swiftcVersionArg = "--version"

/// Always start with 'xcode-select --install'. It'll prompt the user to install the command lines tools if that has not
/// happened yet; otherwise, it terminates with a warning and a non-zero exit code and doesn't do anything.
///
func xcodeSelectInstall() throws {

  do {
    let xcodeSelectInstallProcess = try Process.run(xcodeSelectPath, arguments: ["--install"])
    xcodeSelectInstallProcess.waitUntilExit()
  } catch {
    throw FatalError.couldNotRun(commandName: xcodeSelectPath.path())
  }
}

/// Serach for tool configurations support Swift projects.
///
/// - Throws: If there is a fatal error preventing us from finding toolchains, the functions throws an error, which
///     might be a `FatalError`.
/// - Returns: Any Swift toolchain configurations found.
///
@MainActor
func findSwift() throws -> [ToolConfiguration] {

  try xcodeSelectInstall()
  if let version = try version(of: swiftcPath,
                               arguments: [swiftcVersionArg],
                               matching: versionRegexpWithPrefix)
  {

    let configuration = ToolConfiguration(languageServerPath: sourcekitLspPath,
                                          compilerPath: swiftcPath,
                                          version: version)
    return [configuration]

  } else { return [] }
}
