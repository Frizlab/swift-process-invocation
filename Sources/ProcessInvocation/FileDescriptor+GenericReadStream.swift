import Foundation

import StreamReader
import SystemPackage



#if compiler(>=6.0)
extension FileDescriptor : @retroactive GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		return try read(into: UnsafeMutableRawBufferPointer(start: buffer, count: len))
	}
	
}
#else
extension FileDescriptor : GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		return try read(into: UnsafeMutableRawBufferPointer(start: buffer, count: len))
	}
	
}
#endif
typealias FileDescriptorReader = GenericStreamReader
