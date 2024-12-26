import Foundation

import SystemPackage
import UnwrapOrThrow



public struct RawLineWithSource : Equatable, Hashable, CustomStringConvertible {
	
	public var line: Data
	public var eol: Data
	
	public var fd: FileDescriptor
	
	public func strLineWithSource(encoding: String.Encoding = .utf8) throws -> LineWithSource {
		return try LineWithSource(line: strLine(encoding: encoding), eol: strEOL(encoding: encoding), fd: fd)
	}
	
	public func strLine(encoding: String.Encoding = .utf8) throws -> String {
		return try String(data: line, encoding: encoding) ?! Err.invalidDataEncoding(line)
	}
	
	public func strEOL(encoding: String.Encoding = .utf8) throws -> String {
		return try String(data: eol, encoding: encoding) ?! Err.invalidDataEncoding(line)
	}
	
	public func strLineOrHex(encoding: String.Encoding = .utf8) -> String {
		return String(data: line, encoding: encoding) ?? line.reduce("", { $0 + String(format: "%02x", $1) })
	}
	
	public func strEOLOrHex(encoding: String.Encoding = .utf8) -> String {
		return String(data: eol, encoding: encoding) ?? line.reduce("", { $0 + String(format: "%02x", $1) })
	}
	
	public var description: String {
		return "RawLineWithSource<\(fd.rawValue), 0x\(line.reduce("", { $0 + String(format: "%02x", $1) })), 0x\(eol.reduce("", { $0 + String(format: "%02x", $1) }))>"
	}
	
}


public struct LineWithSource : Equatable, Hashable, CustomStringConvertible {
	
	public var line: String
	public var eol:  String
	
	public var fd: FileDescriptor
	
	public var description: String {
		let escapedLine: String = line.unicodeScalars.lazy.map{ $0.escaped(asASCII: true) }.joined()
		let escapedEOL:  String = eol .unicodeScalars.lazy.map{ $0.escaped(asASCII: true) }.joined()
		return #"RawLineWithSource<\#(fd.rawValue), "\#(escapedLine)", "\#(escapedEOL)">"#
	}
	
}
