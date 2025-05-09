//
//  FindHaskell.swift
//  macos-toolchain-finder
//
//  Created by Manuel M T Chakravarty on 30/04/2025.
//

import Foundation
import RegexBuilder


private let homebrewPrefix            = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"] ?? "/opt/homebrew"
private let bashPath                  = URL(fileURLWithPath: "/bin/bash", isDirectory: false)
private let homebrewPath              = URL(fileURLWithPath: "\(homebrewPrefix)/bin/brew", isDirectory: false)
private let ghcName                   = "ghc"
private let haskellLanguageServerName = "haskell-language-server"

@MainActor
private let hlsConfigRegexp = Regex {
  "haskell-language-server version: "
  Capture{ versionRegexp }
  " (GHC: "
  Capture{ versionRegexp }
  ") (PATH: "
  OneOrMore(.anyNonNewline)
  ")"
}

/// Serach for tool configurations support Haskell projects.
///
/// - Throws: If there is a fatal error preventing us from finding toolchains, the functions throws an error, which
///     might be a `FatalError`.
/// - Returns: Any Swift toolchain configurations found.
///
@MainActor
func findHaskell() throws -> [ToolConfiguration] {
  (try findHaskellHomebrew()) + (try findHaskellGHCup())
}

@MainActor
func findHaskellHomebrew() throws -> [ToolConfiguration] {

  func ghcInstallations(for package: String) throws -> [(String, URL)] {

    // We should be able to query Homebrew for the paths like this:
    //    return try query(managerPath: homebrewPath, arguments: ["list", package]) { line in
    // But Ruby doesn't like our invocations. Hence, we use 'ls'.
    return try query(managerPath: bashPath,
                     arguments: ["-c", "/bin/ls \(homebrewPrefix)/Cellar/\(package)/*/bin/\(ghcName)"]) { line in

      // NB: We match for 'ghc' (without version number) for the executable path as we need an executable that HLS will
      //     pick up. We also don't want to resolve links for that reason.
      let url = URL(filePath: line)
      if url.lastPathComponent == ghcName {
        if let (_, ghcVersion) = try version(of: url, arguments: ["--version"], matching: versionRegexpWithPrefix) {

          return (String(ghcVersion), url)

        } else { return nil }

      } else { return nil }
    }
  }

  func configurations(for package: String, using ghcs: [(String, URL)]) throws -> [ToolConfiguration] {

    // Same Homebrew/Ruby problem as in 'ghcInstallations(for:)'.
    return try query(managerPath: bashPath,
                     arguments: ["-c", "/bin/ls \(homebrewPrefix)/Cellar/\(package)/*/bin/\(haskellLanguageServerName)-*", package]) { line in

      // NB: Some entries may be symbolic links. By resolving them, we may get duplicates, but duplicate configurations
      //     are removed anyways at the end of the process.
      let url = URL(filePath: line).resolvingSymlinksInPath()
      if url.lastPathComponent.hasPrefix(haskellLanguageServerName) {

        if let (_, hlsVersion, ghcVersion) = try version(of: url, arguments: ["--version"], matching: hlsConfigRegexp) {

          if let ghcUrl = ghcs.first(where: { $0.0 == ghcVersion })?.1 {

            return ToolConfiguration(languageServerPath: url,
                                     compilerPath: ghcUrl,
                                     toolPath: URL(filePath: homebrewPrefix).appending(component: "bin"),
                                     version: "\(hlsVersion)-\(ghcVersion)")

          } else { return nil }

        } else { return nil }

      } else { return nil }
    }
  }

  let ghcs = try query(managerPath: homebrewPath, arguments: ["list"]) { line in
    if line.hasPrefix(ghcName) { line } else { nil }
  }
  let ghcVersions = try ghcs.flatMap(ghcInstallations(for:))

  let haskellLanguageServers = try query(managerPath: homebrewPath, arguments: ["list"]) { line in
    if line.hasPrefix(haskellLanguageServerName) { line } else { nil }
  }
  // Deduplicate all configurations from the found HLS packages.
  return Array(Set(try haskellLanguageServers.flatMap{ try configurations(for: $0, using: ghcVersions) }))
}

func findHaskellGHCup() throws -> [ToolConfiguration] {
  return []
}
