import Foundation

public enum FileUtils {
  public static var temporaryDirectory: URL {
    URL(fileURLWithPath: NSTemporaryDirectory())
  }

  public static func makeTemporaryFile(prefix: String, in directory: URL? = nil) throws -> URL {
    let directory = directory ?? temporaryDirectory
    var template = directory.appendingPathComponent("\(prefix)XXXXXX").path
    let result = try template.withUTF8 { template in
      let copy = UnsafeMutableBufferPointer<CChar>.allocate(capacity: template.count + 1)
      defer { copy.deallocate() }
      template.copyBytes(to: copy)
      copy[template.count] = 0
      guard mkstemp(copy.baseAddress!) != -1 else {
        throw CartonCoreError("Failed to make a temporary file")
      }
      return String(cString: copy.baseAddress!)
    }
    return URL(fileURLWithPath: result)
  }

  public static func makeTemporaryDirectory(prefix: String, in directory: URL? = nil) throws -> URL {
    let directory = directory ?? temporaryDirectory
    var template = directory.appendingPathComponent("\(prefix)XXXXXX").path
    let result = try template.withUTF8 { template in
      let copy = UnsafeMutableBufferPointer<CChar>.allocate(capacity: template.count + 1)
      defer { copy.deallocate() }
      template.copyBytes(to: copy)
      copy[template.count] = 0
      guard let result = mkdtemp(copy.baseAddress!) else {
        throw CartonCoreError("Failed to make a temporary directory")
      }
      return String(cString: result)
    }
    return URL(fileURLWithPath: result)
  }
}
