import Foundation

import Logging

import ProcessInvocationBridge



public enum ProcessInvocationConstants {
	
	public static let bridgePathEnvVarName: String = "SWIFTPROCESSINVOCATION_BRIDGE_PATH"
	public static let bridgeExecutableName: String = processInvocationBridgeName
	
}

typealias Constants = ProcessInvocationConstants
