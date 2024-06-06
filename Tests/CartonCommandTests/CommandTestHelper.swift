// Copyright 2024 Carton contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArgumentParser
import XCTest
import CartonHelpers
import CartonKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

struct CommandTestError: Swift.Error & CustomStringConvertible {
  init(_ description: String) {
    self.description = description
  }

  var description: String
}

extension Optional {
  func unwrap(_ name: String) throws -> Wrapped {
    guard let self else {
      throw CommandTestError("\(name) is none")
    }
    return self
  }
}

extension Duration {
  var asTimeInterval: TimeInterval {
    let (sec, atto) = components
    return TimeInterval(sec) + TimeInterval(atto) / 1e18
  }
}

func findExecutable(name: String) throws -> AbsolutePath {
  let whichBin = "/usr/bin/which"
  let process = Process()
  process.executableURL = URL(fileURLWithPath: whichBin)
  process.arguments = [name]
  let output = Pipe()
  process.standardOutput = output
  try process.run()
  process.waitUntilExit()
  guard process.terminationStatus == EXIT_SUCCESS else {
    throw CommandTestError("Executable \(name) was not found: status=\(process.terminationStatus)")
  }
  let outputData = output.fileHandleForReading.readDataToEndOfFile()
  guard let string = String(data: outputData, encoding: .utf8) else {
    throw CommandTestError("Output from \(whichBin) is not UTF-8 string")
  }
  let path = string.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !path.isEmpty else {
    throw CommandTestError("Output from \(whichBin) is empty")
  }
  return try AbsolutePath(validating: path)
}

func findSwiftExecutable() throws -> AbsolutePath {
  try findExecutable(name: "swift")
}

struct SwiftRunProcess {
  var process: CartonHelpers.Process
  var output: () -> [UInt8]
}

func swiftRunProcess(
  _ arguments: [String],
  packageDirectory: URL
) throws -> SwiftRunProcess {
  let swiftBin = try findSwiftExecutable().pathString

  var outputBuffer = Array<UInt8>()

  let process = CartonHelpers.Process(
    arguments: [swiftBin, "run"] + arguments,
    workingDirectory: try AbsolutePath(validating: packageDirectory.path),
    outputRedirection: .stream(
      stdout: { (chunk) in
        outputBuffer += chunk
        stdoutStream.write(sequence: chunk)
        stdoutStream.flush()
      }, stderr: { (chunk) in
        stderrStream.write(sequence: chunk)
        stderrStream.flush()
      },
      redirectStderr: false
    )
  )

  try process.launch()

  process.forwardTerminationSignals()

  return SwiftRunProcess(
    process: process,
    output: { outputBuffer }
  )
}

@discardableResult
func swiftRun(_ arguments: [String], packageDirectory: URL) async throws
  -> CartonHelpers.ProcessResult
{
  let process = try swiftRunProcess(arguments, packageDirectory: packageDirectory)
  var result = try await process.process.waitUntilExit()
  result.setOutput(.success(process.output()))
  return result
}

func fetchWebContent(at url: URL, timeout: Duration) async throws -> (response: HTTPURLResponse, body: Data) {
  let session = URLSession.shared

  let request = URLRequest(
    url: url, cachePolicy: .reloadIgnoringCacheData,
    timeoutInterval: timeout.asTimeInterval
  )

  let (body, response) = try await session.data(for: request)

  guard let response = response as? HTTPURLResponse else {
    throw CommandTestError("Response from \(url.absoluteString) is not HTTPURLResponse")
  }

  return (response: response, body: body)
}

func checkServerNameField(response: HTTPURLResponse, expectedPID: Int32) throws {
  guard let string = response.value(forHTTPHeaderField: "Server") else {
    throw CommandTestError("no Server header")
  }
  let field = try Server.ServerNameField.parse(string)

  guard field.name == Server.serverName else {
    throw CommandTestError("invalid server name: \(field)")
  }

  guard field.pid == expectedPID else {
    throw CommandTestError("Expected PID \(expectedPID) but got PID \(field.pid).")
  }
}
