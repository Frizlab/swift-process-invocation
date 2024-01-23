#import "NSTaskHelptender.h"

@import eXtenderZ.HelptenderUtils;



static char PUBLIC_TERMINATION_HANDLER_KEY;

@implementation SPITaskHelptender

+ (void)load
{
#ifdef HPN_eXtenderZ_STATIC
	[HPNCategoriesLoader loadCategories];
#endif
	[self hpn_registerClass:self asHelptenderForProtocol:@protocol(SPITaskExtender)];
}

+ (void)hpn_helptenderHasBeenAdded:(SPITaskHelptender *)helptender
{
	[helptender overrideTerminationHandler];
}

+ (void)hpn_helptenderWillBeRemoved:(SPITaskHelptender *)helptender
{
	[helptender resetTerminationHandler];
}

- (nullable SPITaskTerminationSignature ^)publicTerminationHandler
{
	return objc_getAssociatedObject(self, &PUBLIC_TERMINATION_HANDLER_KEY);
}

- (void)setPublicTerminationHandler:(nullable SPITaskTerminationSignature ^)terminationHandler
{
	objc_setAssociatedObject(self, &PUBLIC_TERMINATION_HANDLER_KEY, terminationHandler, OBJC_ASSOCIATION_COPY);
}

- (void)setTerminationHandler:(nullable SPITaskTerminationSignature ^)terminationHandler
{
	[self setPublicTerminationHandler:terminationHandler];
}

- (void)overrideTerminationHandler
{
	/* For the fun, below is the declaration without the
	 * SPITaskTerminationSignature typealias:
	 *    void (^currentTerminationHandler)(NSTask *) = ((void (^(*)(id, SEL))(NSTask *))HPN_HELPTENDER_CALL_SUPER_NO_ARGS_WITH_SEL_NAME(SPITaskHelptender, terminationHandler));
	 */
	SPITaskTerminationSignature ^currentTerminationHandler = ((SPITaskTerminationSignature ^(*)(id, SEL))HPN_HELPTENDER_CALL_SUPER_NO_ARGS_WITH_SEL_NAME(SPITaskHelptender, terminationHandler));
	[self setPublicTerminationHandler:currentTerminationHandler];
	
	SPITaskTerminationSignature ^newTerminationHandler = ^(NSTask *task) {
		/* The assert below is valid, but it retains self, which we do not want. */
//		NSCAssert(task == self, @"Weird, got a task in handler which is not self.");
		for (id<SPITaskExtender> extender in [task hpn_extendersConformingToProtocol:@protocol(SPITaskExtender)]) {
			SPITaskTerminationSignature ^additionalTerminationHandler = [extender additionalCompletionHandler];
			if (additionalTerminationHandler != NULL) additionalTerminationHandler(task);
		}
		SPITaskTerminationSignature ^terminationHandler = [(SPITaskHelptender *)task publicTerminationHandler];
		if (terminationHandler != NULL) terminationHandler(task);
	};
	((void (*)(id, SEL, SPITaskTerminationSignature ^))HPN_HELPTENDER_CALL_SUPER_WITH_SEL_NAME(SPITaskHelptender, setTerminationHandler:, newTerminationHandler));
}

- (void)resetTerminationHandler
{
	((void (*)(id, SEL, SPITaskTerminationSignature ^))HPN_HELPTENDER_CALL_SUPER_WITH_SEL_NAME(SPITaskHelptender, setTerminationHandler:, self.publicTerminationHandler));
	[self setPublicTerminationHandler:nil];
}

@end
