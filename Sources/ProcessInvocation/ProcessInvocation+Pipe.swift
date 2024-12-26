import Foundation

import StreamReader
import SystemPackage



/* Some utilities to avoid name clash with ProcessInvocation functions and avoid using `Darwin.` which does not exist on Linux.
 * We’ll probably use System methods instead. */
private func globalClose(_ fd: Int32) -> Int32 {close(fd)}
private func globalWrite(_ fd: Int32, _ buf: UnsafeRawPointer!, _ nbyte: Int) -> Int {write(fd, buf, nbyte)}

public extension ProcessInvocation {
	
	/**
	 Returns a simple pipe.
	 Different than using the `Pipe()` object from Foundation because you get control on when the fds are closed.
	 
	 - Important: The `FileDescriptor`s returned **must** be closed manually. */
	static func unownedPipe() throws -> (fdRead: FileDescriptor, fdWrite: FileDescriptor) {
		let pipepointer = UnsafeMutablePointer<CInt>.allocate(capacity: 2)
		defer {pipepointer.deallocate()}
		pipepointer.initialize(to: -1)
		
		guard pipe(pipepointer) == 0 else {
			throw Err.systemError(Errno(rawValue: errno))
		}
		
		let fdRead  = pipepointer.advanced(by: 0).pointee
		let fdWrite = pipepointer.advanced(by: 1).pointee
		assert(fdRead != -1 && fdWrite != -1)
		
		return (FileDescriptor(rawValue: fdRead), FileDescriptor(rawValue: fdWrite))
	}
	
	/**
	 Returns a the read end of a pipe that will stream everything from the stream reader.
	 
	 The data will be read from the stream and sent along to the pipe.
	 At most `maxCacheSize` bytes will be kept in memory from the stream (assuming the stream does not have a bigger internal cache).
	 
	 If at any point reading from the stream fails, an error is logged and the write end of the pipe is closed, effectively ending the data sent in the read end.
	 
	 - Important: If the fd is sent to a subprocess, the fd must be closed after the subprocess is launched. */
	static func readFdOfPipeForStreaming(dataFromReader reader: StreamReader, maxCacheSize: Int = .max) throws -> FileDescriptor {
		let pipe = try ProcessInvocation.unownedPipe()
		
		/* If the reader is a DataReader and the source data is 0 we can skip the writing and directly close the write fd.
		 * We only check this special case as reading from the reader can be a blocking operation and we want to avoid that in an init. */
		if (reader as? DataReader)?.sourceDataSize != 0 {
			let fhWrite = FileHandle(fileDescriptor: pipe.fdWrite.rawValue)
			fhWrite.writeabilityHandler = { fh in
				let closeFH = {
					fhWrite.writeabilityHandler = nil
					if globalClose(fh.fileDescriptor) == -1 {
						Conf.logger?.error("Failed closing write end of fd for pipe to swift; pipe might stay open forever.", metadata: ["errno": "\(errno)", "errno-str": "\(Errno(rawValue: errno).localizedDescription)"])
					}
				}
				
				do {
					try reader.peekData(size: Swift.max(0, maxCacheSize - (reader.currentStreamReadPosition - reader.currentReadPosition)), allowReadingLess: true, { _ in })
					try reader.peekData(size: reader.currentStreamReadPosition - reader.currentReadPosition, allowReadingLess: false, { bytes in
						let (writtenNow, readError) = {
							guard bytes.count > 0 else {
								return (0, Int32(0))
							}
							
							var ret: Int
							repeat {
								Conf.logger?.trace("Trying to write on write end of pipe.", metadata: ["bytes_count": "\(bytes.count)"])
								ret = globalWrite(fh.fileDescriptor, bytes.baseAddress!, bytes.count)
							} while ret == -1 && errno == EINTR
							return (ret, errno)
						}()
						
						if writtenNow > 0 {
							do    {try reader.readData(size: writtenNow, allowReadingLess: false, { _ in /*nop: we only update the current read position.*/ })}
							catch {Conf.logger?.critical("Invalid StreamReader (or internal logic error)! Reading from the stream failed but the data should already be in the buffer.")}
						} else if writtenNow < 0 {
							if [EAGAIN, EWOULDBLOCK].contains(readError) {
								/* We ignore the write error and let the writeabilityHandler call us back (let’s hope it will!). */
								Conf.logger?.debug("Failed write end of fd for pipe to swift with temporary error (EAGAIN or EWOULDBLOCK). We wait for the writeabilityHandler to be called again.", metadata: ["errno": "\(readError)", "errno-str": "\(Errno(rawValue: readError).localizedDescription)"])
							} else {
								Conf.logger?.error("Failed writing in fd for pipe. We close the stream now.", metadata: ["errno": "\(readError)", "errno-str": "\(Errno(rawValue: readError).localizedDescription)"])
								closeFH()
							}
						}
						
						if reader.streamHasReachedEOF, reader.currentReadPosition == reader.currentStreamReadPosition {
							/* We have reached the end of the stream; let’s close the stream! */
							Conf.logger?.trace("Closing write end of pipe fd.")
							closeFH()
						}
					})
				} catch {
					Conf.logger?.error("Failed reading from the stream for writing to pipe. Bailing.", metadata: ["error": "\(error)"])
					closeFH()
				}
			}
		} else {
			try pipe.fdWrite.close()
		}
		
		return pipe.fdRead
	}
	
	static func readFdOfPipeForStreaming(data: Data) throws -> FileDescriptor {
		return try readFdOfPipeForStreaming(dataFromReader: DataReader(data: data))
	}
	
}
