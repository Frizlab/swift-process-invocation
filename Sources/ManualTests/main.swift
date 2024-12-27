import Foundation

import CLTLogger
import Logging
import ProcessInvocation
import StreamReader
import SystemPackage

/* Old remark (fixed not):
 *    Launch the manual test like so:
 *     echo yolo | ./.build/debug/ManualTests
 *    For some reasons actually typing stuff in the Terminal (no “echo yolo |”) does not work
 *     (probably some buffered read as stdin is not a tty for cat, or some other sh*t I don’t really get). */



LoggingSystem.bootstrap{ _ in var ret = CLTLogger(); ret.logLevel = .trace; return ret }
let logger = Logger(label: "com.xcode-actions.manual-process-invocation-tests")

//print("stdin is valid: \(isValidFileDescriptor(.standardInput))")
//do    {print("stdin is blocking: \(try isFileDescriptorBlocking(.standardInput))")}
//catch {print("stdin is blocking retrieval failed: \(error)")}
//do    {print("stdin path: \(try getFilePath(from: .standardInput))")}
//catch {print("stdin path retrieval failed: \(error)")}

//let stdin = FileHandle.standardInput.fileDescriptor
//let ptr = UnsafeMutableRawPointer.allocate(byteCount: 42, alignment: 1)
//print("yolo: \(read(stdin, ptr, 1))")

//let reader = FileHandleReader(stream: FileHandle.standardInput, bufferSize: 30, bufferSizeIncrement: 30, underlyingStreamReadSizeLimit: 1)
//while let line = try reader.readLine()?.line {
//	print(line.reduce("", { $0 + String(format: "%02x", $1) }))
//}

do {
	let fd = try! FileDescriptor.open("/dev/null", .readOnly)
	defer {_ = try? fd.close()}
	
	/*let p = Process()
	p.executableURL = URL(fileURLWithPath: "./toto")
	try p.run()
	/* Fails with permission denied (not sure why though). */
//	if setpgid(p.processIdentifier, getpgid(0)) != 0 {
//		p.terminate()
//		throw Errno(rawValue: errno)
//	}
	if tcsetpgrp(FileDescriptor.standardInput.rawValue, getpgid(p.processIdentifier)) != 0 {
		p.terminate()
		throw Errno(rawValue: errno)
	}
	p.waitUntilExit()*/
	
//	let pi = ProcessInvocation("swift-sh", "-c", """
//		import Foundation
//		import StreamReader // @xcode-actions/stream-reader ~> 3.5
//		let reader = FileHandleReader(stream: FileHandle.standardInput, bufferSize: 30, bufferSizeIncrement: 30)
//		while let line = try reader.readLine()?.line {
//			print(line.reduce("", { $0 + String(format: "%02x", $1) }))
//		}
//		""", stdinRedirect: .none/*, fileDescriptorsToSend: [fd: fd]*/
//	)
//	let pi = ProcessInvocation("/bin/cat", stdinRedirect: .send(Data("yo".utf8)))
//	let pi = ProcessInvocation("/bin/cat", stdinRedirect: .none(), stdoutRedirect: .none, stderrRedirect: .none, fileDescriptorsToSend: [fd: fd])
//	for try await line in pi {
//		print("From cat: \(line.strLineOrHex())")
//	}
	
#if swift(>=5.7)
	/* Try to read one line from ProcessInvocation and then one using StreamReader. */
	let pi = ProcessInvocation("head", "-n", "1")
	for try await line in pi {
		print("From head: \(line.strLineOrHex())")
	}
	let reader = FileDescriptorReader(stream: FileDescriptor.standardInput, bufferSize: 32, bufferSizeIncrement: 16, underlyingStreamReadSizeLimit: 1)
	if let line = try reader.readLine()?.line {
		print("From reader: \(String(data: line, encoding: .utf8) ?? line.reduce("", { $0 + String(format: "%02x", $1) }))")
	} else {
		print("Failed reading line from stream reader.")
	}
#endif
} catch {
	print("Failed running the process: \(error)")
}



/* *************
   MARK: - Utils
   ************* */

func isValidFileDescriptor(_ fd: FileDescriptor) -> Bool {
	return fcntl(fd.rawValue, F_GETFL) != -1 || errno != EBADF
}

func getFilePath(from fd: FileDescriptor) throws -> String {
#if canImport(Darwin)
	let filePath = UnsafeMutableRawPointer.allocate(byteCount: Int(PATH_MAX), alignment: MemoryLayout<Int8>.alignment)
	defer {filePath.deallocate()}
	
	guard fcntl(fd.rawValue, F_GETPATH, filePath) != -1 else {
		throw Errno(rawValue: errno)
	}
	return String(cString: UnsafePointer(filePath.assumingMemoryBound(to: CChar.self)))
#else
	throw Errno.notSupported
#endif
}

func isFileDescriptorBlocking(_ fd: FileDescriptor) throws -> Bool {
	let curFlags = fcntl(fd.rawValue, F_GETFL)
	guard curFlags != -1 else {
		throw Errno(rawValue: errno)
	}
	return (curFlags & O_NONBLOCK) != 0
}

func setRequireNonBlockingIO(on fd: FileDescriptor, logChange: Bool) throws {
	let curFlags = fcntl(fd.rawValue, F_GETFL)
	guard curFlags != -1 else {
		throw Errno(rawValue: errno)
	}
	
	let newFlags = curFlags | O_NONBLOCK
	guard newFlags != curFlags else {
		/* Nothing to do */
		return
	}
	
	if logChange {
		/* We only log for fd that were not ours */
		logger.warning("Setting O_NONBLOCK option on fd.", metadata: ["fd": "\(fd)"])
	}
	guard fcntl(fd.rawValue, F_SETFL, newFlags) != -1 else {
		throw Errno(rawValue: errno)
	}
}

typealias FileDescriptorReader = GenericStreamReader





/* The toto.swift file content when we used it to debug the fact that cat did not receive anything from stdin when run in the Terminal.
import Foundation
import SystemPackage

import StreamReader // @xcode-actions/stream-reader ~> 3.5



print("inside toto: stdin is valid: \(isValidFileDescriptor(.standardInput))")
do    {print("inside toto: stdin is blocking: \(try isFileDescriptorBlocking(.standardInput))")}
catch {print("inside toto: stdin is blocking retrieval failed: \(error)")}
do    {print("inside toto: stdin path: \(try getFilePath(from: .standardInput))")}
catch {print("inside toto: stdin path retrieval failed: \(error)")}

//let stdin = FileHandle.standardInput.fileDescriptor
//let ptr = UnsafeMutableRawPointer.allocate(byteCount: 42, alignment: 1)
//print("yolo: \(read(stdin, ptr, 1))")

//print(isatty(FileHandle.standardInput.fileDescriptor))

let reader = FileHandleReader(stream: FileHandle.standardInput, bufferSize: 30, bufferSizeIncrement: 30, underlyingStreamReadSizeLimit: 1)
while let line = try reader.readLine()?.line {
	print(line.reduce("", { $0 + String(format: "%02x", $1) }))
}



/* *************
   MARK: - Utils
   ************* */

func isValidFileDescriptor(_ fd: FileDescriptor) -> Bool {
	return fcntl(fd.rawValue, F_GETFL) != -1 || errno != EBADF
}

func getFilePath(from fd: FileDescriptor) throws -> String {
	let filePath = UnsafeMutableRawPointer.allocate(byteCount: Int(PATH_MAX), alignment: MemoryLayout<Int8>.alignment)
	defer {filePath.deallocate()}

	guard fcntl(fd.rawValue, F_GETPATH, filePath) != -1 else {
		throw Errno(rawValue: errno)
	}
	return String(cString: UnsafePointer(filePath.assumingMemoryBound(to: CChar.self)))
}

func isFileDescriptorBlocking(_ fd: FileDescriptor) throws -> Bool {
	let curFlags = fcntl(fd.rawValue, F_GETFL)
	guard curFlags != -1 else {
		throw Errno(rawValue: errno)
	}
	return (curFlags & O_NONBLOCK) != 0
}

func setRequireNonBlockingIO(on fd: FileDescriptor) throws {
	let curFlags = fcntl(fd.rawValue, F_GETFL)
	guard curFlags != -1 else {
		throw Errno(rawValue: errno)
	}

	let newFlags = curFlags | O_NONBLOCK
	guard newFlags != curFlags else {
		/* Nothing to do */
		return
	}

	guard fcntl(fd.rawValue, F_SETFL, newFlags) != -1 else {
		throw Errno(rawValue: errno)
	}
}
*/
