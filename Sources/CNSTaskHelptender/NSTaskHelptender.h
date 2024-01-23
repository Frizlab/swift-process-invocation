@import Foundation;

@import eXtenderZ;



NS_ASSUME_NONNULL_BEGIN

/* We declare a typealias to the function signature, not the block type directly for elegancy:
 *    <https://news.ycombinator.com/item?id=13437182>. */
typedef void SPITaskTerminationSignature(NSTask * _Nonnull);

@protocol SPITaskExtender <HPNExtender>

@property(readonly) SPITaskTerminationSignature ^additionalCompletionHandler;

@end


@interface SPITaskHelptender : NSTask <HPNHelptender>

@end

NS_ASSUME_NONNULL_END
