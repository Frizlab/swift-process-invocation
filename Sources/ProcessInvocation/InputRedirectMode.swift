import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

import StreamReader



/**
 How to redirect the output file descriptors? */
public enum InputRedirectMode {
	
	/** 
	 The stream will be left as-is.
	 
	 If `setFgPgID` is set to `true` (default), an attempt is set the foreground group ID associated with the controlling terminal of the fd to the child process group ID.
	 If the attempt fails with the `ENOTTY` error, the error is ignored; otherwise it is not. */
	case none(setFgPgID: Bool = true)
	/** This is the equivalent of using ``InputRedirectMode/send(_:)`` with an empty data. */
	case fromNull
	/** Send the given data to the subprocess (done with a pipe). */
	case sendFromReader(DataReader)
	/**
	 The stream should be redirected from this fd.
	 If `giveOwnership` is true, the fd will be closed when the process has run.
	 Otherwise it is your responsability to close it when needed. */
	case fromFd(FileDescriptor, giveOwnership: Bool, setFgPgID: Bool = false)
	
	public static func send(_ data: Data) -> Self {
		let reader = DataReader(data: data)
		return .sendFromReader(reader)
	}
	
}
