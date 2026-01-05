//
//  EncryptionUtility.h
//  TheT2BoysSN-Changer
//
//  Reconstructed from IDA dump
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>

NS_ASSUME_NONNULL_BEGIN

@interface EncryptionUtility : NSObject

// Class methods
+ (NSData *)generateRandomBytesWithLength:(NSUInteger)length;
+ (NSData *)generateKeyFromPassphrase:(NSString *)passphrase salt:(NSData *)salt;
+ (NSData *)decryptData:(NSData *)data decryptionKey:(NSData *)key;

// Instance methods
- (NSData *)encryptData:(NSData *)data encryptionKey:(NSData *)key;
- (void)performEncryptionAndDecryption;

@end

NS_ASSUME_NONNULL_END
