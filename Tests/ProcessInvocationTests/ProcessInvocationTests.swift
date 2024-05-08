import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif
import XCTest

import CLTLogger
import Logging
import StreamReader

#if canImport(CGNUSourceExportsForTests)
import CGNUSourceExportsForTests
#endif

@testable import ProcessInvocation



#if !canImport(Darwin)
private let posix_openpt = spift_posix_openpt
private let grantpt      = spift_grantpt
private let unlockpt     = spift_unlockpt
private let ptsname      = spift_ptsname
#endif

final class ProcessInvocationTests : XCTestCase {
	
	override class func setUp() {
		super.setUp()
		bootstrapIfNeeded()
		Conf.logger = logger
		
		/* Let’s set the path for the bridge (some methods need it). */
		setenv(Constants.bridgePathEnvVarName, productsDirectory.path, 1)
	}
	
	func testProcessSpawnWithWorkdirAndEnvChange() throws {
		/* LINUXASYNC START --------- */
		let group = DispatchGroup()
		group.enter()
		Task{do{
			/* LINUXASYNC STOP --------- */
			let checkCwdAndEnvPath = Self.scriptsPath.appending("check-cwd+env.swift")
			
			let workingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
			try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true, attributes: nil)
			defer {_ = try? FileManager.default.removeItem(at: workingDirectory)}
			
			guard let realpathDir = realpath(workingDirectory.path, nil) else {
				struct CannotGetRealPath : Error {var sourcePath: String}
				throw CannotGetRealPath(sourcePath: workingDirectory.path)
			}
			let expectedWorkingDirectory = String(cString: realpathDir)
			
			let expectedEnvValue = UUID().uuidString
			
			let PATH = getenv("PATH").flatMap{ String(cString: $0) }
			let (outputs, exitCode, exitReason) = try await ProcessInvocation(checkCwdAndEnvPath, "SWIFTPROCESSINVOCATION_TEST_VALUE", workingDirectory: workingDirectory, environment:  ["SWIFTPROCESSINVOCATION_TEST_VALUE": expectedEnvValue, "PATH": PATH].compactMapValues{ $0 }, signalsToProcess: [])
				.invokeAndGetOutput(checkValidTerminations: false)
			XCTAssertEqual(exitCode, 0)
			XCTAssertEqual(exitReason, .exit)
			XCTAssertEqual(outputs.filter{ $0.fd == .standardOutput }.reduce("", { $0 + $1.line + $1.eol }), expectedWorkingDirectory + "\n" + expectedEnvValue + "\n")
			
			/* LINUXASYNC START --------- */
			group.leave()
		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
		group.wait()
		/* LINUXASYNC STOP --------- */
	}
	
	func testProcessSpawnAndStreamStdin() throws {
		/* LINUXASYNC START --------- */
		let group = DispatchGroup()
		group.enter()
		Task{do{
			/* LINUXASYNC STOP --------- */
			struct ReadError : Error {}
			for file in ["three-lines.txt", "big.txt"] {
				let filePath = Self.filesPath.appending(file)
				let fileContents = try String(contentsOf: filePath.url)
				
				let fd = try FileDescriptor.open(filePath, .readOnly)
				let (outputs, exitStatus, exitReason) = try await ProcessInvocation("/bin/cat", stdinRedirect: .fromFd(fd, giveOwnership: false), signalsToProcess: []).invokeAndGetOutput(checkValidTerminations: false)
				try fd.close()
				
				XCTAssertEqual(exitStatus, 0)
				XCTAssertEqual(exitReason, .exit)
				
				XCTAssertFalse(outputs.contains(where: { $0.fd == .standardError }))
				XCTAssertEqual(outputs.filter{ $0.fd == .standardOutput }.reduce("", { $0 + $1.line + $1.eol }), fileContents)
			}
			
			/* LINUXASYNC START --------- */
			group.leave()
		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
		group.wait()
		/* LINUXASYNC STOP --------- */
	}
	
	func testProcessSpawnAndStreamStdoutAndStderr() throws {
		/* LINUXASYNC START --------- */
		let group = DispatchGroup()
		group.enter()
		Task{do{
			/* LINUXASYNC STOP --------- */
			struct ReadError : Error {}
			let scriptURL = Self.scriptsPath.appending("slow-and-interleaved-output.swift")
			
			let n = 3 /* Not lower than 2 to get fdSwitchCount high enough */
			let t = 0.25
			
			var fdSwitchCount = 0
			var previousFd: FileDescriptor?
			var linesByFd = [RawLineWithSource]()
			let (terminationStatus, terminationReason) = try await ProcessInvocation(scriptURL, "\(n)", "\(t)", signalsToProcess: [])
				.invokeAndStreamOutput(checkValidTerminations: false, outputHandler: { rawLine, _, _ in
					if previousFd != rawLine.fd {
						fdSwitchCount += 1
						previousFd = rawLine.fd
					}
					linesByFd.append(rawLine)
				})
			let textLinesByFd = try textOutputFromOutputs(linesByFd)
			
			XCTAssertGreaterThan(fdSwitchCount, 2)
			
			XCTAssertEqual(terminationStatus, 0)
			XCTAssertEqual(terminationReason, .exit)
			
			let expectedStdout = (1...n).map{ String(repeating: "*", count: $0)           }.joined(separator: "\n") + "\n"
			let expectedStderr = (1...n).map{ String(repeating: "*", count: (n - $0 + 1)) }.joined(separator: "\n") + "\n"
			
			XCTAssertEqual(textLinesByFd[FileDescriptor.standardOutput] ?? "", expectedStdout)
			/* We do not check for equality here because swift sometimes log errors on stderr before launching the script… */
			XCTAssertTrue((textLinesByFd[FileDescriptor.standardError] ?? "").hasSuffix(expectedStderr))
			
			/* LINUXASYNC START --------- */
			group.leave()
		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
		group.wait()
		/* LINUXASYNC STOP --------- */
	}
	
	func testProcessTerminationHandler() throws {
		var wentIn = false
		let (_, g) = try ProcessInvocation("/bin/cat", stdinRedirect: .fromNull, signalsToProcess: []).invoke(outputHandler: { _,_,_ in }, terminationHandler: { p in
			wentIn = true
		})
		
		/* No need to wait on the process anymore */
		g.wait()
		
		XCTAssertTrue(wentIn)
	}
	
	func testNonStandardFdCapture() throws {
		for _ in 0..<3 {
			let scriptURL = Self.scriptsPath.appending("write-500-lines.swift")
			
			let n = 50
			
			/* Do **NOT** use a `Pipe` object! (Or dup the fds you get from it).
			 * Pipe closes both ends of the pipe on dealloc, but we need to close one at a specific time and leave the other open
			 * (it is closed by the invoke function). */
			let (fdRead, fdWrite) = try ProcessInvocation.unownedPipe()
			
			var count = 0
			let pi = ProcessInvocation(
				scriptURL, "\(n)", "\(fdWrite.rawValue)",
				stdoutRedirect: .toNull, stderrRedirect: .toNull,
				signalsToProcess: [],
				fileDescriptorsToSend: [fdWrite: fdWrite], additionalOutputFileDescriptors: [fdRead]
			)
			let (p, g) = try pi.invoke{ lineResult, _, _ in
				guard let rawLine = try? lineResult.get() else {
					return XCTFail("got output error: \(lineResult)")
				}
				guard rawLine.fd != FileDescriptor.standardError else {
					/* When a Swift script is launched, swift can output some shit on stderr… */
					NSLog("%@", "Got err from script: \(rawLine.line)")
					return
				}
				
				XCTAssertEqual(rawLine.fd, fdRead)
				XCTAssertEqual(rawLine.line, Data("I will not leave books on the ground.".utf8))
				XCTAssertEqual(rawLine.eol, Data("\n".utf8))
				Thread.sleep(forTimeInterval: 0.05) /* Greater than wait time in script. */
				if count == 0 {
					Thread.sleep(forTimeInterval: 3)
				}
				
				count += 1
			}
			
			p.waitUntilExit() /* Not needed anymore, but should not hurt either. */
			
			XCTAssertLessThan(count, n)
			
			let r = g.wait(timeout: .now() + .seconds(7))
			XCTAssertEqual(r, .success)
			XCTAssertEqual(count, n)
		}
	}
	
	func testStandardFdCaptureButWithSentFds() throws {
		for _ in 0..<3 {
			let scriptURL = Self.scriptsPath.appending("write-500-lines.swift")
			
			let n = 50
			
			/* Do **NOT** use a `Pipe` object! (Or dup the fds you get from it).
			 * Pipe closes both ends of the pipe on dealloc, but we need to close one at a specific time and leave the other open
			 * (it is closed by the invoke function). */
			let (fdRead, fdWrite) = try ProcessInvocation.unownedPipe()
			
			var count = 0
			let pi = ProcessInvocation(
				scriptURL, "\(n)", "\(FileDescriptor.standardOutput.rawValue)",
				signalsToProcess: [],
				fileDescriptorsToSend: [fdWrite: fdWrite], additionalOutputFileDescriptors: [fdRead]
			)
			let (p, g) = try pi.invoke{ lineResult, _, _ in
				guard let rawLine = try? lineResult.get() else {
					return XCTFail("got output error: \(lineResult)")
				}
				guard rawLine.fd != FileDescriptor.standardError else {
					/* When a Swift script is launched, swift can output some shit on stderr… */
					NSLog("%@", "Got err from script: \(rawLine.line)")
					return
				}
				
				XCTAssertEqual(rawLine.fd, .standardOutput)
				XCTAssertEqual(rawLine.line, Data("I will not leave books on the ground.".utf8))
				XCTAssertEqual(rawLine.eol, Data("\n".utf8))
				Thread.sleep(forTimeInterval: 0.05) /* Greater than wait time in script. */
				if count == 0 {
					Thread.sleep(forTimeInterval: 3)
				}
				
				count += 1
			}
			
			p.waitUntilExit() /* Not needed anymore, but should not hurt either. */
			
			XCTAssertLessThan(count, n)
			
			let r = g.wait(timeout: .now() + .seconds(7))
			XCTAssertEqual(r, .success)
			XCTAssertEqual(count, n)
		}
	}
	
	/* This disabled (disabled because too long) test and some variants of it have allowed the discovery of some bugs:
	 *   - Leaks of file descriptors;
	 *   - Pipe fails to allocate new fds, but Pipe object init is non-fallible in Swift…
	 *      so we check either way (now we do not use the Pipe object anyway, we get more control over the lifecycle of the fds);
	 *   - Race between executable end and io group, leading to potentially closed fds _while setting up a new run_, leading to a lot of weird behaviour, such as:
	 *       - `process not launched exception`,
	 *       - assertion failures in the spawn and stream method (same fd added twice in a set, which is not possible),
	 *       - dead-lock with the io group being waited on forever,
	 *       - partial data being read, etc.;
	 *   - Some fds were not closed at the proper location (this was more likely discovered through `testNonStandardFdCapture`, but this one helped too IIRC). */
	func disabledTestSpawnProcessWithResourceStarvingFirstDraft() throws {
		/* LINUXASYNC START --------- */
		let group = DispatchGroup()
		group.enter()
		Task{do{
			/* LINUXASYNC STOP --------- */
			
			/* It has been observed that on my computer, things starts to go bad when there are roughly 6500 fds open.
			 * So we start by opening 6450 fds. */
			for _ in 0..<6450 {
				_ = try FileDescriptor.open("/dev/random", .readOnly)
			}
			for i in 0..<5000 {
				NSLog("%@", "***** NEW RUN: \(i+1) *****")
				let outputs = try await ProcessInvocation("/bin/sh", "-c", "echo hello", signalsToProcess: [])
					.invokeAndGetOutput(encoding: .utf8)
				XCTAssertFalse(outputs.contains(where: { $0.fd != .standardOutput }))
				XCTAssertEqual(outputs.reduce("", { $0 + $1.line + $1.eol }), "hello\n")
			}
			
			/* LINUXASYNC START --------- */
			group.leave()
		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
		group.wait()
		/* LINUXASYNC STOP --------- */
	}
	
	/* Disabled because unreliable (sometimes works, sometimes not). */
	func disabledTestSpawnProcessWithResourceStarving() async throws {
		/* Let’s starve the fds first */
		var fds = Set<FileDescriptor>()
		while let fd = try? FileDescriptor.open("/dev/random", .readOnly) {fds.insert(fd)}
		defer {fds.forEach{ try? $0.close() }}
		
		func releaseRandomFd() throws {
			guard let randomFd = fds.randomElement() else {
				throw Err.internalError("We starved the fds without opening a lot of files it seems.")
			}
			try randomFd.close()
			fds.remove(randomFd)
		}
		
		let pi = ProcessInvocation("/bin/sh", "-c", "echo hello", signalsToProcess: [])
		
		/* Now we try and use Process */
		await tempAsyncAssertThrowsError(try await pi.invokeAndGetOutput(encoding: .utf8))
		
		/* We release two fds. */
		try releaseRandomFd()
		try releaseRandomFd()
		/* Using process should still fail, but with error when opening Pipe for stderr, not stdout.
		 * To verify, the test would have to be modified, but the check would not be very stable, so we simply verify we still get a failure. */
		await tempAsyncAssertThrowsError(try await pi.invokeAndGetOutput(encoding: .utf8))
		
		/* Now let’s release more fds. Hopefully enough to get enough available. */
		try releaseRandomFd()
		try releaseRandomFd()
		try releaseRandomFd()
		try releaseRandomFd()
		try releaseRandomFd()
		let outputs = try await pi.invokeAndGetRawOutput()
		XCTAssertEqual(try textOutputFromOutputs(outputs), [.standardOutput: "hello\n"])
	}
	
	func testPathSearch() throws {
		/* LINUXASYNC START --------- */
		let group = DispatchGroup()
		group.enter()
		Task{do{
			/* LINUXASYNC STOP --------- */
			
			let spyScriptPath = FilePath("spy.swift")
			let nonexistentScriptPath = FilePath(" this-file-does-not-and-must-not-exist.txt ") /* We hope nobody will create an executable with this name in the PATH */
			
			let notExecutableScriptComponent = FilePath.Component("not-executable.swift")
			let notExecutablePathInCwd = FilePath(root: nil, components: ".", notExecutableScriptComponent)
			
			let checkCwdAndEnvScriptComponent = FilePath.Component("check-cwd+env.swift")
			let checkCwdAndEnvPath      = FilePath(root: nil, components:      checkCwdAndEnvScriptComponent)
			let checkCwdAndEnvPathInCwd = FilePath(root: nil, components: ".", checkCwdAndEnvScriptComponent)
			
			let currentWD = FileManager.default.currentDirectoryPath
			defer {FileManager.default.changeCurrentDirectoryPath(currentWD)}
			
			await tempAsyncAssertThrowsError(try await ProcessInvocation(nonexistentScriptPath, signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertThrowsError(try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, customPATH: nil, signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertThrowsError(try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, customPATH: .some(nil), signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertThrowsError(try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, customPATH: [""], signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertThrowsError(try await ProcessInvocation(checkCwdAndEnvPathInCwd, usePATH: true, customPATH: [Self.scriptsPath], signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertNoThrow(try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, customPATH: [Self.scriptsPath], signalsToProcess: []).invokeAndGetRawOutput())
			
			await tempAsyncAssertThrowsError(try await ProcessInvocation(spyScriptPath, usePATH: false,                                                 signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertThrowsError(try await ProcessInvocation(spyScriptPath, usePATH: true,  customPATH: [Self.filesPath],                   signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertNoThrow(try await ProcessInvocation(spyScriptPath,     usePATH: true,  customPATH: [Self.scriptsPath],                 signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertNoThrow(try await ProcessInvocation(spyScriptPath,     usePATH: true,  customPATH: [Self.scriptsPath, Self.filesPath], signalsToProcess: []).invokeAndGetRawOutput())
#if !canImport(Darwin)
			/* On Linux, the error when trying to execute a non-executable file is correct (no permission), and so we don’t try next path available. */
			await tempAsyncAssertThrowsError(try await ProcessInvocation(spyScriptPath, usePATH: true,  customPATH: [Self.filesPath, Self.scriptsPath], signalsToProcess: []).invokeAndGetRawOutput())
#else
			/* On macOS the error is file not found, even if the actual problem is a permission thing. */
			await tempAsyncAssertNoThrow(try await ProcessInvocation(spyScriptPath,     usePATH: true,  customPATH: [Self.filesPath, Self.scriptsPath], signalsToProcess: []).invokeAndGetRawOutput())
#endif
			
			
			let curPath = getenv("PATH").flatMap{ String(cString: $0) }
			
			do {
				let envBefore = EnvAndCwd().removing(keys: ["MANPATH"])
				let fd = try FileDescriptor.open("/dev/null", .readOnly)
				let output = try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, customPATH: [Self.scriptsPath], stdoutRedirect: .capture, stderrRedirect: .toNull, signalsToProcess: [], fileDescriptorsToSend: [fd: fd], lineSeparators: .none)
					.invokeAndGetRawOutput()
				let data = try XCTUnwrap(output.onlyElement)
				XCTAssert(data.eol.isEmpty)
				let envInside = try JSONDecoder().decode(EnvAndCwd.self, from: data.line).removing(keys: ["MANPATH"])
				let envAfter = EnvAndCwd().removing(keys: ["MANPATH"])
				XCTAssertEqual(envBefore, envInside)
				XCTAssertEqual(envBefore, envAfter)
#if false
				print("diff1: \(Set(envBefore.env.keys).subtracting(envInside.env.keys))")
				print("diff2: \(Set(envInside.env.keys).subtracting(envBefore.env.keys))")
#endif
			}
			
			defer {
				if let curPath = curPath {setenv("PATH", curPath, 1)}
				else                     {unsetenv("PATH")}
			}
			let path = curPath ?? ""
			let newPath = path + (path.isEmpty ? "" : ":") + Self.scriptsPath.string
			setenv("PATH", newPath, 1)
			
			await tempAsyncAssertThrowsError(try await ProcessInvocation(nonexistentScriptPath, usePATH: true, signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertThrowsError(try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, customPATH: .some(nil), signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertThrowsError(try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, customPATH: [""], signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertThrowsError(try await ProcessInvocation(checkCwdAndEnvPathInCwd, usePATH: true, customPATH: nil, signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertThrowsError(try await ProcessInvocation(checkCwdAndEnvPathInCwd, usePATH: false, signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertNoThrow(try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, customPATH: nil, signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertNoThrow(try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, signalsToProcess: []).invokeAndGetRawOutput())
			
			FileManager.default.changeCurrentDirectoryPath(Self.scriptsPath.string)
			await tempAsyncAssertNoThrow(try await ProcessInvocation(checkCwdAndEnvPath, usePATH: true, customPATH: [""], signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertNoThrow(try await ProcessInvocation(checkCwdAndEnvPathInCwd, usePATH: true, customPATH: nil, signalsToProcess: []).invokeAndGetRawOutput())
			await tempAsyncAssertNoThrow(try await ProcessInvocation(checkCwdAndEnvPathInCwd, usePATH: false, signalsToProcess: []).invokeAndGetRawOutput())
			/* Sadly the error we get is a file not found on macOS.
			 * On Linux, the error makes sense. */
			FileManager.default.changeCurrentDirectoryPath(Self.filesPath.string)
			await tempAsyncAssertThrowsError(try await ProcessInvocation(notExecutablePathInCwd, usePATH: false, signalsToProcess: []).invokeAndGetRawOutput())
			
			/* LINUXASYNC START --------- */
			group.leave()
		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
		group.wait()
		/* LINUXASYNC STOP --------- */
	}
	
	/* From swift-sh failure on Linux. */
	func testRedirectToPTY() throws {
		/* LINUXASYNC START --------- */
		let group = DispatchGroup()
		group.enter()
		Task{do{
			/* LINUXASYNC STOP --------- */
			
			var slaveRawFd: Int32 = -1
			var masterRawFd: Int32 = -1
			guard openpty(&masterRawFd, &slaveRawFd, nil/*name*/, nil/*termp*/, nil/*winp*/) == 0 else {
				struct CannotOpenTTYError : Error {var errmsg: String}
				throw CannotOpenTTYError(errmsg: Errno(rawValue: errno).localizedDescription)
			}
			/* Note: No defer in which we close the fds, they will be closed by ProcessInvocation. */
			let slaveFd = FileDescriptor(rawValue: slaveRawFd)
			let masterFd = FileDescriptor(rawValue: masterRawFd)
			let output = try await ProcessInvocation(
				"bash", "-c", "echo ok",
				stdinRedirect: .none(), stdoutRedirect: .toFd(slaveFd, giveOwnership: true), stderrRedirect: .toNull, additionalOutputFileDescriptors: [masterFd],
				lineSeparators: .newLine(unix: true, legacyMacOS: false, windows: true/* Because of the pty, I think. */)
			).invokeAndGetRawOutput()
			XCTAssertEqual(output, [.init(line: Data([0x6f, 0x6b]), eol: Data([0x0d, 0x0a]), fd: masterFd)])
			
			/* LINUXASYNC START --------- */
			group.leave()
		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
		group.wait()
		/* LINUXASYNC STOP --------- */
	}
	
	/* Variant of testRedirectToPTY but using the POSIX method of opening the PTY.
	 * Thank God the behavior seems to be the same! */
	func testRedirectToPTYUsingPOSIX() throws {
		/* LINUXASYNC START --------- */
		let group = DispatchGroup()
		group.enter()
		Task{do{
			/* LINUXASYNC STOP --------- */
			
			/* Open master PTY fd first. */
			let masterRawFd = posix_openpt(O_RDWR)
			guard masterRawFd > 0 else {
				throw Errno(rawValue: errno)
			}
			
			/* Create a cleanup block if there are errors opening the slave fd. */
			let masterFd = FileDescriptor(rawValue: masterRawFd)
			let closeMasterKeepErrno = {
				let curErr = errno
				if (try? masterFd.close()) == nil {
					Self.logger.warning("Failed to close master PTY fd after grantpt or unlockpt failed.")
				}
				errno = curErr
			}
			
			/* Grant and unlock the PTY fd (not what that does, but whateer…). */
			guard grantpt(masterRawFd) == 0, unlockpt(masterRawFd) == 0 else {
				closeMasterKeepErrno()
				throw Errno(rawValue: errno)
			}
			
			/* Retrieve the slave PTY name. */
			guard let cSlaveFilename = ptsname(masterRawFd) else {
				closeMasterKeepErrno()
				throw Errno(rawValue: errno)
			}
			/* Copy the return of ptsname, whose memory is not guaranteed to last.
			 * In theory I think I could pass the return of ptsname directly to the open call next,
			 *  but my source (<https://stackoverflow.com/a/74285225>) did the copy. */
			let slaveFilename = String(cString: cSlaveFilename)
			
			/* Open the slave PTY. */
			let slaveRawFd = slaveFilename.withCString{ open($0, O_RDWR) }
			guard slaveRawFd > 0 else {
				closeMasterKeepErrno()
				throw Errno(rawValue: errno)
			}
			let slaveFd = FileDescriptor(rawValue: slaveRawFd)
			
			/* Note: No defer in which we close the fds, they will be closed by ProcessInvocation. */
			let output = try await ProcessInvocation(
				"bash", "-c", "echo ok",
				stdinRedirect: .none(), stdoutRedirect: .toFd(slaveFd, giveOwnership: true), stderrRedirect: .toNull, additionalOutputFileDescriptors: [masterFd],
				lineSeparators: .customCharacters([0x6b])
			).invokeAndGetRawOutput()
			XCTAssertEqual(output, [.init(line: Data([0x6f]), eol: Data([0x6b]), fd: masterFd), .init(line: Data([0x0d, 0x0a]), eol: Data(), fd: masterFd)])
			
			/* LINUXASYNC START --------- */
			group.leave()
		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
		group.wait()
		/* LINUXASYNC STOP --------- */
	}
	
	func testSendDataToStdin() throws {
		/* LINUXASYNC START --------- */
		let group = DispatchGroup()
		group.enter()
		Task{do{
			/* LINUXASYNC STOP --------- */
			
			let data = Data([0, 1, 2, 3, 4, 5])
			let (outputs, exitStatus, exitReason) = try await ProcessInvocation(
				"/bin/cat", stdinRedirect: .send(data),
				signalsToProcess: [],
				lineSeparators: .none
			).invokeAndGetRawOutput(checkValidTerminations: false)
			
			XCTAssertEqual(exitStatus, 0)
			XCTAssertEqual(exitReason, .exit)
			
			XCTAssertEqual(outputs.count, 1)
			XCTAssertFalse(outputs.contains(where: { $0.fd == .standardError }))
			XCTAssertEqual(outputs.first?.line, data)
			
			/* LINUXASYNC START --------- */
			group.leave()
		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
		group.wait()
		/* LINUXASYNC STOP --------- */
	}
	
	func testBashPipeLikeFlow() throws {
		/* LINUXASYNC START --------- */
		let group = DispatchGroup()
		group.enter()
		Task{do{
			/* LINUXASYNC STOP --------- */
			
			let (fdRead, fdWrite) = try ProcessInvocation.unownedPipe()
			let invocation1 = ProcessInvocation("printf", "%s", "1+2", stdoutRedirect: .toFd(fdWrite, giveOwnership: true))
			_ = try invocation1.invoke(outputHandler: { _, _, _ in })
			let invocation2 = ProcessInvocation("bc", stdinRedirect: .sendFromReader(FileDescriptorReader(stream: fdRead, bufferSize: 3, bufferSizeIncrement: 1)))
			let output = try await invocation2.invokeAndGetOutput()
			XCTAssertEqual(output, [.init(line: "3", eol: "\n", fd: .standardOutput)])
			
			/* LINUXASYNC START --------- */
			group.leave()
		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
		group.wait()
		/* LINUXASYNC STOP --------- */
	}
	
	/* Works, but so slow. */
//	func testSendBiggerDataToStdin() throws {
//		/* LINUXASYNC START --------- */
//		let group = DispatchGroup()
//		group.enter()
//		Task{do{
//			/* LINUXASYNC STOP --------- */
//			
//			let data = Data(Array(repeating: [0, 1, 2, 3, 4, 5], count: 64 * 1024 * 1024).flatMap{ $0 })
//			let (outputs, exitStatus, exitReason) = try await ProcessInvocation(
//				"/bin/cat", stdinRedirect: .send(data),
//				signalsToProcess: [],
//				lineSeparators: .none
//			).invokeAndGetRawOutput(checkValidTerminations: false)
//			
//			XCTAssertEqual(exitStatus, 0)
//			XCTAssertEqual(exitReason, .exit)
//			
//			XCTAssertEqual(outputs.count, 1)
//			XCTAssertFalse(outputs.contains(where: { $0.fd == .standardError }))
//			XCTAssertEqual(outputs.first?.line, data)
//			
//			/* LINUXASYNC START --------- */
//			group.leave()
//		} catch {XCTFail("Error thrown during async test: \(error)"); group.leave()}}
//		group.wait()
//		/* LINUXASYNC STOP --------- */
//	}
	
	/* While XCTest does not have support for async for XCTAssertThrowsError */
	private func tempAsyncAssertThrowsError<T>(_ block: @autoclosure () async throws -> T, _ message: @escaping @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (_ error: Error) -> Void = { _ in }) async {
		do    {_ = try await block(); XCTAssertThrowsError(    {             }(), message(), file: file, line: line, errorHandler)}
		catch {                       XCTAssertThrowsError(try { throw error }(), message(), file: file, line: line, errorHandler)}
	}
	
	/* While XCTest does not have support for async for XCTAssertNoThrow */
	private func tempAsyncAssertNoThrow<T>(_ block: @autoclosure () async throws -> T, _ message: @escaping @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (_ error: Error) -> Void = { _ in }) async {
		do    {_ = try await block(); XCTAssertNoThrow(    {             }(), message(), file: file, line: line)}
		catch {                       XCTAssertNoThrow(try { throw error }(), message(), file: file, line: line)}
	}
	
	private func textOutputFromOutputs(_ outputs: [RawLineWithSource]) throws -> [FileDescriptor: String] {
		var res = [FileDescriptor: String]()
		for rawLine in outputs {
			let line = try rawLine.strLineWithSource(encoding: .utf8)
			res[line.fd, default: ""] += line.line + line.eol
		}
		return res
	}
	
	/** Returns the path to the built products directory. */
	private static var productsDirectory: URL {
#if os(macOS)
		for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
			return bundle.bundleURL.deletingLastPathComponent()
		}
		fatalError("couldn't find the products directory")
#else
		return Bundle.main.bundleURL
#endif
	}
	
	private struct EnvAndCwd : Codable, Equatable {
#if os(macOS)
		static var defaultRemovedKeys = Set<String>(
			arrayLiteral:
			/* Keys removed by spawn (or something else). */
			"DYLD_FALLBACK_LIBRARY_PATH", "DYLD_FALLBACK_FRAMEWORK_PATH", "DYLD_LIBRARY_PATH", "DYLD_FRAMEWORK_PATH",
			/* Keys added by Swift launcher (presumably). */
			"CPATH", "LIBRARY_PATH", "SDKROOT"
		)
#else
		/* Keys added by swift launcher (presumably). */
		static var defaultRemovedKeys = Set<String>(arrayLiteral: "LD_LIBRARY_PATH")
#endif
		
		var cwd: String
		var env: [String: String]
		
		init(removedEnvKeys: Set<String> = Self.defaultRemovedKeys) {
			env = [String: String]()
			cwd = FileManager.default.currentDirectoryPath
			
			/* Fill env */
			var curEnvPtr = environ
			while let curVarValC = curEnvPtr.pointee {
				defer {curEnvPtr = curEnvPtr.advanced(by: 1)}
				let curVarVal = String(cString: curVarValC)
				let split = curVarVal.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
				assert(split.count == 2) /* If this assert is false, the environ variable is invalid. As we’re a test script we don’t care about being fully safe. */
				guard !removedEnvKeys.contains(split[0]) else {continue}
				env[split[0]] = split[1] /* Same, if we get the same var twice, environ is invalid so we override without worrying. */
			}
		}
		
		init(cwd: String, env: [String: String]) {
			self.cwd = cwd
			self.env = env
		}
		
		func removing(keys: Set<String>) -> EnvAndCwd {
			var ret = EnvAndCwd(cwd: cwd, env: env)
			keys.forEach{ ret.env.removeValue(forKey: $0) }
			return ret
		}
	}
	
}
