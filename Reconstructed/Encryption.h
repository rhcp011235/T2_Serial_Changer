//
//  Encryption.h
//  TheT2BoysSN-Changer
//
//  Reconstructed from IDA dump
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Encryption : NSObject

// Key derivation with configurable parameters
+ (NSData *)derivedKeyFromPassphrase:(NSString *)passphrase
                                salt:(NSData *)salt
                          iterations:(NSUInteger)iterations
                           keyLength:(NSUInteger)keyLength;

// AES-256 encryption/decryption
+ (NSData *)AES256EncryptData:(NSData *)data withKey:(NSData *)key;
+ (NSData *)AES256DecryptData:(NSData *)data withKey:(NSData *)key;

// String encryption/decryption with passphrase
+ (NSString *)encryptString:(NSString *)string withPassphrase:(NSString *)passphrase;
+ (NSString *)decryptString:(NSString *)encryptedString withPassphrase:(NSString *)passphrase;

@end

// NSData category for AES encryption
@interface NSData (AES256)

- (NSData *)AES256EncryptWithKey:(NSData *)key;
- (NSData *)AES256DecryptWithKey:(NSData *)key;
- (NSData *)AES256EncryptWithKey2:(NSData *)key initializationVector:(NSData *)iv;
- (NSData *)AES256DecryptWithKey2:(NSData *)key initializationVector:(NSData *)iv;

@end

NS_ASSUME_NONNULL_END
