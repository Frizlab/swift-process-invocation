import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

import ProcessInvocation



/* Launch like so:
 *  echo yolo | ./.build/debug/ManualTests
 * For some reasons actually typing stuff in the Terminal does not work (probably some buffered read as stdin is not a tty for cat, or some other sh*t I don’t really get).
 *
 * Apart from the glitch above, it seems to work correctly when not sending file descriptors.
 * If we do send fds, not much works… */
//let fd = FileDescriptor(rawValue: FileHandle(forReadingAtPath: "/dev/null")!.fileDescriptor)
do {
	for try await line in ProcessInvocation("/bin/cat", stdinRedirect: .none/*, fileDescriptorsToSend: [fd: fd]*/) {
		print("From cat: \(line.strLineOrHex())")
	}
} catch {
	print("Failed running the process: \(error)")
}
