//
//  FindHaskell.swift
//  macos-toolchain-finder
//
//  Created by Manuel M T Chakravarty on 30/04/2025.
//

import Foundation
import RegexBuilder


private let homebrewPrefix            = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"] ?? "/opt/homebrew"
private let whichPath                 = URL(fileURLWithPath: "/usr/bin/which")
private let bashPath                  = URL(fileURLWithPath: "/bin/bash", isDirectory: false)
private let homebrewPath              = URL(fileURLWithPath: "\(homebrewPrefix)/bin/brew", isDirectory: false)
private let ghcName                   = "ghc"
private let cabalName                 = "cabal"
private let haskellLanguageServerName = "haskell-language-server"
private let ghcUpName                 = "ghcup"

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

  func installations(of toolName: String, for package: String) throws -> [(String, URL)] {

    // We should be able to query Homebrew for the paths like this:
    //    return try query(managerPath: homebrewPath, arguments: ["list", package]) { line in
    // But Ruby doesn't like our invocations. Hence, we use 'ls'.
    return try query(managerPath: bashPath,
                     arguments: ["-c", "/bin/ls \(homebrewPrefix)/Cellar/\(package)/*/bin/\(toolName)"]) { line in

      // NB: We match for 'ghc' (without version number) for the executable path as we need an executable that HLS will
      //     pick up. We also don't want to resolve links for that reason.
      let url = URL(filePath: line)
      if url.lastPathComponent == toolName {
        if let (_, toolVersion) = try version(of: url, arguments: ["--version"], matching: versionRegexpWithPrefix) {

          return (String(toolVersion), url)

        } else { return nil }

      } else { return nil }
    }
  }

  func configurations(for package: String,
                      using ghcs: [(String, URL)],
                      with cabal: (String, URL)?)
  throws -> [ToolConfiguration]
  {
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
                                     packageManagerPath: cabal?.1,
                                     toolBinPath: URL(filePath: homebrewPrefix).appending(component: "bin"),
                                     version: "\(hlsVersion)-\(ghcVersion)",
                                     packageManagerVersion: cabal?.0)

          } else { return nil }

        } else { return nil }

      } else { return nil }
    }
  }

  let ghcs = try query(managerPath: homebrewPath, arguments: ["list"]) { line in
    if line.hasPrefix(ghcName) { line } else { nil }
  }
  let ghcVersions = try ghcs.flatMap{ try installations(of: ghcName, for: $0) }

  let cabals = try query(managerPath: homebrewPath, arguments: ["list"]) { line in
    if line.hasPrefix(cabalName) { line } else { nil }
  }
  let cabalVersions = try cabals.flatMap{ try installations(of: cabalName, for: $0) }.sorted{ lhs, rhs in lhs.0 < rhs.0 }

  let haskellLanguageServers = try query(managerPath: homebrewPath, arguments: ["list"]) { line in
    if line.hasPrefix(haskellLanguageServerName) { line } else { nil }
  }
  // Deduplicate all configurations from the found HLS packages.
  return Array(Set(try haskellLanguageServers.flatMap{ try configurations(for: $0,
                                                                          using: ghcVersions,
                                                                          with: cabalVersions.last) }))
}

@MainActor
func findHaskellGHCup() throws -> [ToolConfiguration] {

  enum GhcUpFlag: String, Equatable {
    case none
    case latest
    case recommended

    init(_ string: String) {
      if string.contains(Self.recommended.rawValue) {
        self = .recommended
      } else if string.contains(Self.latest.rawValue) {
        self = .latest
      } else {
        self = .none
      }
    }
  }

  if let ghcUpPath = try query(managerPath: whichPath, arguments: [ghcUpName], processLine: { $0 })
                       .map({ URL(filePath: $0) })
                       .first
  {

    func installations(of toolName: String, for version: String) throws -> [(String, URL)] {
      return try query(managerPath: ghcUpPath, arguments: ["--offline", "whereis", toolName, version]) {
        (version, URL(filePath: $0))
      }
    }

    func configurations(for hlsVersion: String,
                        using ghcs: [(String, URL)],
                        with cabal: (String, URL)?)
    throws -> [ToolConfiguration]
    {
      // 'ghcup whereis hls' gives us the path of the 'haskell-language-server-wrapper' without any indication of the
      // supported GHC versions. However, 'haskell-language-server-<ghc-version>' executables are located in the same
      // directory; hence, we enumerate those.
      let nestedResults = try query(managerPath: ghcUpPath, arguments: ["--offline", "whereis", "hls", hlsVersion]) { wrapperPath in
        let hlsExecutableDirectory = URL(fileURLWithPath: wrapperPath).deletingLastPathComponent(),
            files                  = try FileManager.default.contentsOfDirectory(at: hlsExecutableDirectory,
                                                                                 includingPropertiesForKeys: nil)
        return files.compactMap { url in
          if let (_, ghcVersion) = url.lastPathComponent.firstMatch(of: Capture{ versionRegexp })?.output {

            if let ghcUrl = ghcs.first(where: { $0.0 == ghcVersion })?.1 {

              return ToolConfiguration(languageServerPath: url,
                                       compilerPath: ghcUrl,
                                       packageManagerPath: cabal?.1,
                                       toolBinPath: URL(filePath: homebrewPrefix).appending(component: "bin"),
                                       version: "\(hlsVersion)-\(ghcVersion)", packageManagerVersion: cabal?.0)

            } else { return nil }

          } else { return nil }
        }
      }
      return Array(nestedResults.joined())
    }

    let hlsArguments                  = ["--offline", "list", "--tool=hls", "--show-criteria=installed", "--raw-format"],
        haskellLanguageServerVersions = try query(managerPath: ghcUpPath, arguments: hlsArguments) { line in
          if let (_, version) = try versionRegexpWithPrefix.firstMatch(in: line)?.output { String(version) } else { nil }
        }

    let ghcArguments = ["--offline", "list", "--tool=ghc", "--show-criteria=installed", "--raw-format"],
        ghcVersions  = try query(managerPath: ghcUpPath, arguments: ghcArguments) { line in
          if let (_, version) = try versionRegexpWithPrefix.firstMatch(in: line)?.output { String(version) } else { nil }
        },
        ghcInstallations = try ghcVersions.map{ try installations(of: ghcName, for: $0) }.joined()

    let cabalArguments = ["--offline", "list", "--tool=cabal", "--show-criteria=installed", "--raw-format"],
        cabalVersions  = try query(managerPath: ghcUpPath, arguments: cabalArguments) { line in
          if let (_, version) = try versionRegexpWithPrefix.firstMatch(in: line)?.output {
            (String(version), GhcUpFlag(line))
          } else { nil }
        },
        preferredCabalVersion = if let recommendedCabalVersion = cabalVersions.first(where: { $0.1 == .recommended }) {
          recommendedCabalVersion.0
        } else if let latestCabalVersion = cabalVersions.first(where: { $0.1 == .latest }) {
          latestCabalVersion.0
        } else { cabalVersions.first?.0 },
        cabalInstallations = try preferredCabalVersion.flatMap{ try installations(of: cabalName, for: $0) }

    return try haskellLanguageServerVersions.flatMap{ try configurations(for: $0,
                                                                         using: Array(ghcInstallations),
                                                                         with: cabalInstallations?.first )}

  } else { return [] }
}
