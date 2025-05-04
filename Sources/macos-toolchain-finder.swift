// Tool to detect language toolchains for a specific set of programming languages on macOS. Currently, three
// languages are supported: Agda, Haskell, and Swift. More specifically, three language server protocol implementations
// for these three languages are supported, namely Agda Language Server, Haskell Language Server, and SourceKit-LSP,
// which supports projects using Swift, C, and C++ files.

import Foundation
import ArgumentParser


enum Language: String, ExpressibleByArgument {
  case agda
  case haskell
  case swift
}

@main
struct MacosToolchainFinder: AsyncParsableCommand {

  @Argument(help: "The programming language whose toolchains we want to find: agda, haskell, or swift.")
  var language: Language

}

extension MacosToolchainFinder {

  func run() async throws {

    do {

      let configurations: [ToolConfiguration] = switch language {
                                                  case .agda:
                                                    []
                                                  case .haskell:
                                                    try await findHaskell()
                                                  case .swift:
                                                    try await findSwift()
                                                  }
      if let json = try? JSONEncoder().encode(configurations) {
        print(String(data: json, encoding: .utf8) ?? "")
      } else {
        throw FatalError.couldNotConvertToJSON
      }

    } catch let err {
      print("Error: \(err)")
    }
  }
}
