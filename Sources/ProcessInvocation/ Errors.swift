import Foundation

import SystemPackage



public enum ProcessInvocationError : Error {
	
	/**
	 Some methods need `SWIFTPROCESSINVOCATION_BRIDGE_PATH` to be set and throw this error if it is not. */
	case bridgePathEnvVarNotSet
	
	case outputReadError(Error)
	case invalidDataEncoding(Data)
	case unexpectedSubprocessExit(terminationStatus: Int32, terminationReason: Process.TerminationReason)
	
	case systemError(Errno)
	case internalError(String)
	
}

typealias Err = ProcessInvocationError
