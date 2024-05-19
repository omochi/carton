import Foundation

public final class Future<Value>: @unchecked Sendable {
  public struct Sink: Sendable {
    public init() {
      self.future = Future<Value>()
    }

    public let future: Future<Value>

    public func resolve(_ result: Value) {
      future.resolve(result)
    }
  }

  private init() {
    self.lock = NSLock()
    self.result = nil
    self.awaiters = []
  }

  private let lock: NSLock
  private var result: Value?
  private var awaiters: [CheckedContinuation<Value, Never>]

  private func resolve(_ result: Value) {
    lock.withLock {
      self.result = result
      for awaiter in awaiters {
        awaiter.resume(returning: result)
      }
    }
  }

  public var value: Value {
    get async {
      return await withCheckedContinuation { (continuation) in
        self.lock.withLock {
          if let result {
            continuation.resume(returning: result)
            return
          }

          self.awaiters.append(continuation)
        }
      }
    }
  }
}
