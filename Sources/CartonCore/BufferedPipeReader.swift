import Foundation

public final class BufferedPipeReader: @unchecked Sendable {
  public init() {
    self.lock = NSLock()
    self.buffer = Data()
    self.resultSink = Future.Sink()

    let pipe = Pipe()
    self.pipe = pipe

    pipe.fileHandleForReading.readabilityHandler = { (file) in
      self.write(chunk: file.availableData)
    }
  }

  private let lock: NSLock
  private var buffer: Data
  private let resultSink: Future<Data>.Sink

  public let pipe: Pipe

  private func write(chunk: Data) {
    lock.withLock {
      if chunk.isEmpty {
        pipe.fileHandleForReading.readabilityHandler = nil
        resultSink.resolve(buffer)
      } else {
        buffer.append(chunk)
      }
    }
  }

  public var output: Data {
    get async {
      await resultSink.future.value
    }
  }
}
