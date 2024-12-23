/* From officectl. */

import Foundation
#if canImport(SystemPackage)
import SystemPackage
#elseif canImport(System)
import System
#endif
import XCTest

import CLTLogger
import Logging



public extension XCTestCase {
	
	static var hasBootstrapped = false
	static func bootstrapIfNeeded() {
		guard !hasBootstrapped else {return}
		defer {hasBootstrapped = true}
		
		LoggingSystem.bootstrap({ id, metadataProvider in
			/* Note: CLTLoggers do not have IDs, so we do not use the id parameter of the handler. */
			var ret = CLTLogger(metadataProvider: metadataProvider)
			ret.logLevel = .trace
			return ret
		}, metadataProvider: nil)
	}
	
	static let logger: Logger = {
		var logger = Logger(label: "com.xcode-actions.process-invocation.tests")
		logger.logLevel = .trace
		return logger
	}()
	
	static let testsDataPath: FilePath = {
		return FilePath(#filePath)
			.removingLastComponent().removingLastComponent().removingLastComponent()
			.appending("TestsData")
	}()
	static let testsDataURL: URL = {
		testsDataPath.url
	}()
	
	static let scriptsPath: FilePath = {
		return testsDataPath.appending("scripts")
	}()
	
	static let filesPath: FilePath = {
		return testsDataPath.appending("files")
	}()
	
}


extension FilePath {
	
	var url: URL {
		return URL(fileURLWithPath: string)
	}
	
}


extension Collection {
	
	var onlyElement: Element? {
		guard let e = first, count == 1 else {
			return nil
		}
		return e
	}
	
}
