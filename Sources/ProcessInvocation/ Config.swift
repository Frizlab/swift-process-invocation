import Foundation

import Logging



/** A container to hold the properties that can modify the behaviour of the module. */
public enum ProcessInvocationConfig {
	
	public static var logger: Logging.Logger? = {
		return Logger(label: "com.xcode-actions.process-invocation")
	}()
	
}

typealias Conf = ProcessInvocationConfig
