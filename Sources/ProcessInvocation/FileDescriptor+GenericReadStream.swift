import Foundation

import StreamReader
import SystemPackage



extension FileDescriptor : @retroactive GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		return try read(into: UnsafeMutableRawBufferPointer(start: buffer, count: len))
	}
	
}
