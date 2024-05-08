import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

import SignalHandling



extension ProcessInvocation {
	
	@available(*, deprecated, message: "Use the new InputRedirectMode for stdin redirect.")
	public init(
		_ executable: FilePath, _ args: String..., usePATH: Bool = true, customPATH: [FilePath]?? = nil,
		workingDirectory: URL? = nil, environment: [String: String]? = nil,
		stdin: FileDescriptor?, stdoutRedirect: OutputRedirectMode = .capture, stderrRedirect: OutputRedirectMode = .capture,
		signalsToProcess: Set<Signal> = Signal.toForwardToSubprocesses,
		signalHandling: @escaping (Signal) -> SignalHandling = { .default(for: $0) },
		fileDescriptorsToSend: [FileDescriptor /* Value in **child** */: FileDescriptor /* Value in **parent** */] = [:],
		additionalOutputFileDescriptors: Set<FileDescriptor> = [],
		lineSeparators: LineSeparators = .default,
		shouldContinueStreamHandler: ((_ line: RawLineWithSource, _ process: Process) -> Bool)? = nil,
		expectedTerminations: [(Int32, Process.TerminationReason)]?? = nil
	) {
		self.init(
			executable, args: args, usePATH: usePATH, customPATH: customPATH,
			workingDirectory: workingDirectory, environment: environment,
			stdinRedirect: stdin.flatMap{ .fromFd($0, giveOwnership: false) } ?? .fromNull, stdoutRedirect: stdoutRedirect, stderrRedirect: stderrRedirect,
			signalsToProcess: signalsToProcess,
			signalHandling: signalHandling,
			fileDescriptorsToSend: fileDescriptorsToSend,
			additionalOutputFileDescriptors: additionalOutputFileDescriptors,
			lineSeparators: lineSeparators,
			shouldContinueStreamHandler: shouldContinueStreamHandler,
			expectedTerminations: expectedTerminations
		)
	}
	
	@available(*, deprecated, message: "Use the new InputRedirectMode for stdin redirect.")
	public init(
		_ executable: FilePath, args: [String], usePATH: Bool = true, customPATH: [FilePath]?? = nil,
		workingDirectory: URL? = nil, environment: [String: String]? = nil,
		stdin: FileDescriptor?, stdoutRedirect: OutputRedirectMode = .capture, stderrRedirect: OutputRedirectMode = .capture,
		signalsToProcess: Set<Signal> = Signal.toForwardToSubprocesses,
		signalHandling: @escaping (Signal) -> SignalHandling = { .default(for: $0) },
		fileDescriptorsToSend: [FileDescriptor /* Value in **child** */: FileDescriptor /* Value in **parent** */] = [:],
		additionalOutputFileDescriptors: Set<FileDescriptor> = [],
		lineSeparators: LineSeparators = .default,
		shouldContinueStreamHandler: ((_ line: RawLineWithSource, _ process: Process) -> Bool)? = nil,
		expectedTerminations: [(Int32, Process.TerminationReason)]?? = nil
	) {
		self.init(
			executable, args: args, usePATH: usePATH, customPATH: customPATH,
			workingDirectory: workingDirectory, environment: environment,
			stdinRedirect: stdin.flatMap{ .fromFd($0, giveOwnership: false) } ?? .fromNull, stdoutRedirect: stdoutRedirect, stderrRedirect: stderrRedirect,
			signalsToProcess: signalsToProcess,
			signalHandling: signalHandling,
			fileDescriptorsToSend: fileDescriptorsToSend,
			additionalOutputFileDescriptors: additionalOutputFileDescriptors,
			lineSeparators: lineSeparators,
			shouldContinueStreamHandler: shouldContinueStreamHandler,
			expectedTerminations: expectedTerminations
		)
	}
	
}
