// swift-tools-version:5.5
import PackageDescription

import Foundation


let swiftSettings: [SwiftSetting] = []
//let swiftSettings: [SwiftSetting] = [.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])]


/* Detect if we need the eXtenderZ.
 * If we do (on Apple platforms where the non-public Foundation implementation is used), the eXtenderZ should be able to be imported.
 * See Process+Utils for reason why we use the eXtenderZ. */
let useXtenderZ = (NSStringFromClass(Process().classForCoder) != "NSTask")
/* Do we need the _GNU_SOURCE exports? This allows using execvpe on Linux. */
#if !os(Linux)
let needsGNUSourceExports = false
#else
let needsGNUSourceExports = true
#endif

let isXcode = ProcessInfo.processInfo.environment["__CFBundleIdentifier"]?.lowercased().contains("xcode") ?? false
let executableName = if isXcode {"ProcessInvocationBridge"} else {"swift-process-invocation-bridge"}


let package = Package(
	name: "swift-process-invocation",
	platforms: [.macOS(.v12)/* FilePath is unusable before macOS 12. */],
	products: [
		.library(name: "ProcessInvocation", targets: ["ProcessInvocation"]),
		/* A launcher for forwarding fds when needed. */
		.executable(name: executableName, targets: ["ProcessInvocationBridge"])
	],
	dependencies: {
		var res = [Package.Dependency]()
		res.append(.package(url: "https://github.com/apple/swift-argument-parser.git",         from: "1.2.2"))
		res.append(.package(url: "https://github.com/apple/swift-log.git",                     from: "1.5.2"))
		res.append(.package(url: "https://github.com/Frizlab/UnwrapOrThrow.git",               from: "1.0.1-rc"))
		res.append(.package(url: "https://github.com/xcode-actions/clt-logger.git",            from: "0.5.1"))
		res.append(.package(url: "https://github.com/xcode-actions/stream-reader.git",         from: "3.5.0"))
		res.append(.package(url: "https://github.com/xcode-actions/swift-signal-handling.git", from: "1.1.0"))
#if !canImport(System)
		res.append(.package(url: "https://github.com/apple/swift-system.git",                  from: "1.0.0"))
#endif
		if useXtenderZ {
			res.append(.package(url: "https://github.com/xcode-actions/eXtenderZ.git",          from: "1.0.7"))
		}
		return res
	}(),
	targets: {
		var res = [Target]()
		
		res.append(.target(name: "ProcessInvocation", dependencies: {
			var res = [Target.Dependency]()
			res.append(.product(name: "Logging",        package: "swift-log"))
			res.append(.product(name: "SignalHandling", package: "swift-signal-handling"))
			res.append(.product(name: "StreamReader",   package: "stream-reader"))
			res.append(.product(name: "UnwrapOrThrow",  package: "UnwrapOrThrow"))
#if !canImport(System)
			res.append(.product(name: "SystemPackage",  package: "swift-system"))
#endif
			res.append(.target(name: "CMacroExports"))
			if useXtenderZ {
				res.append(.product(name: "eXtenderZ-static", package: "eXtenderZ"))
				res.append(.target(name: "CNSTaskHelptender"))
			}
			if needsGNUSourceExports {
				res.append(.target(name: "CGNUSourceExports"))
			}
			/* XcodeTools depends (indirectly) on xct to launch processes with additional file descriptors.
			 * To avoid a cyclic dependency, we do not add it in the deps. */
			res.append(.target(name: "ProcessInvocationBridge"))
			return res
		}(), swiftSettings: swiftSettings))
		
		res.append(.executableTarget(name: "ProcessInvocationBridge", dependencies: {
			var res = [Target.Dependency]()
			res.append(.product(name: "ArgumentParser", package: "swift-argument-parser"))
			res.append(.product(name: "CLTLogger",      package: "clt-logger"))
			res.append(.product(name: "Logging",        package: "swift-log"))
#if !canImport(System)
			res.append(.product(name: "SystemPackage",  package: "swift-system"))
#endif
			res.append(.target(name: "CMacroExports"))
			if needsGNUSourceExports {
				res.append(.target(name: "CGNUSourceExports"))
			}
			return res
		}(), swiftSettings: swiftSettings))
		
		res.append(.testTarget(name: "ProcessInvocationTests", dependencies: {
			var res = [Target.Dependency]()
			res.append(.target(name: "ProcessInvocation")) /* <- Tested package */
			res.append(.product(name: "CLTLogger",     package: "clt-logger"))
			res.append(.product(name: "Logging",       package: "swift-log"))
			res.append(.product(name: "StreamReader",  package: "stream-reader"))
#if !canImport(System)
			res.append(.product(name: "SystemPackage",  package: "swift-system"))
#endif
//			res.append(.target(name: "CommonForTests"))
//			res.append(.target(name: "Utils"))
			return res
		}(), swiftSettings: swiftSettings))
		
		/* Some complex macros exported as functions to be used in Swift. */
		res.append(.target(name: "CMacroExports", swiftSettings: swiftSettings))
		if useXtenderZ {
			res.append(.target(name: "CNSTaskHelptender", dependencies: [.product(name: "eXtenderZ-static", package: "eXtenderZ")], swiftSettings: swiftSettings))
		}
		if needsGNUSourceExports {
			res.append(.target(name: "CGNUSourceExports", swiftSettings: swiftSettings))
		}
		
		return res
	}()
)
