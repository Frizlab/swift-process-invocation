#if !canImport(SystemPackage) && !canImport(System)
import Foundation

import StreamReader


public struct FileDescriptor : RawRepresentable, Hashable, Codable {
	public enum OpenMode {
		case readOnly
	}
	public static var standardInput:  FileDescriptor {.init(rawValue: FileHandle.standardInput.fileDescriptor)}
	public static var standardOutput: FileDescriptor {.init(rawValue: FileHandle.standardOutput.fileDescriptor)}
	public static var standardError:  FileDescriptor {.init(rawValue: FileHandle.standardError.fileDescriptor)}
	public static func open(_ path: String, _ mode: OpenMode) -> FileDescriptor {
		let fh = FileHandle(forReadingAtPath: path)!
		return .init(rawValue: fh.fileDescriptor, fh: fh)
	}
	public let rawValue: CInt
	public init(rawValue: CInt) {
		self.rawValue = rawValue
		self.fh = nil
	}
	public func close() throws {
		try fh?.close() ?? {
			let ret = globalClose(rawValue)
			guard ret == 0 else {throw Errno(rawValue: errno)}
		}()
	}
	public func closeAfter<R>(_ body: () throws -> R) throws -> R {
		let r: R
		do    {r = try body()}
		catch {try? close(); throw error}
		try close()
		return r
	}
	/* We do not implement retryOnInterrupt.
	 * I guess FileHandle does it, but it’s far from certain… */
	public func read(into buffer: UnsafeMutableRawBufferPointer, retryOnInterrupt: Bool = true) throws -> Int {
		try FileHandle(fileDescriptor: rawValue).read(buffer.baseAddress!, maxLength: buffer.count)
	}
	private init(rawValue: CInt, fh: FileHandle) {
		self.rawValue = rawValue
		self.fh = fh
	}
	private let fh: FileHandle?
}
/* To avoid the shadowing of close in the dummy FileDescriptor implementation. */
private func globalClose(_ fd: Int32) -> Int32 {close(fd)}

public struct Errno : RawRepresentable, Error, Hashable, Codable {
	public let rawValue: CInt
	public init(rawValue: CInt) {
		self.rawValue = rawValue
	}
}

#endif
