//
//  EncryptionUtility.m
//  TheT2BoysSN-Changer
//
//  Reconstructed from IDA dump
//

#import "EncryptionUtility.h"
#import <Security/Security.h>

// Salt used for key derivation (extracted from binary: cfstr_Ecejwqxaifqgci)
static NSString * const kEncryptionSalt = @"ECEJWQXAIFQGCI";

// PBKDF2 iterations (found at line 7309169 in dump)
static const NSUInteger kPBKDF2Iterations = 10000;

// Key length for AES-256 (found at line 7309170 in dump)
static const NSUInteger kKeyLength = 32;

@implementation EncryptionUtility

#pragma mark - Class Methods

+ (void)initialize {
    // Initialization performed at app launch
    // Original function at 0x1095 in binary
}

+ (NSData *)generateRandomBytesWithLength:(NSUInteger)length {
    // Generate cryptographically secure random bytes
    // Original function declaration at line 13 in dump

    NSMutableData *randomData = [NSMutableData dataWithLength:length];

    if (randomData) {
        int result = SecRandomCopyBytes(kSecRandomDefault,
                                        length,
                                        randomData.mutableBytes);
        if (result != errSecSuccess) {
            return nil;
        }
    }

    return [randomData copy];
}

+ (NSData *)generateKeyFromPassphrase:(NSString *)passphrase salt:(NSData *)salt {
    // Generate encryption key using PBKDF2
    // Original function at line 224 in dump
    // Implementation found around line 7011466

    if (!passphrase || !salt) {
        return nil;
    }

    NSMutableData *derivedKey = [NSMutableData dataWithLength:kKeyLength];

    const char *passwordBytes = [passphrase UTF8String];
    size_t passwordLength = strlen(passwordBytes);

    CCKeyDerivationPBKDF(kCCPBKDF2,
                         passwordBytes,
                         passwordLength,
                         salt.bytes,
                         salt.length,
                         kCCPRFHmacAlgSHA1,
                         (uint)kPBKDF2Iterations,
                         derivedKey.mutableBytes,
                         kKeyLength);

    return [derivedKey copy];
}

+ (NSData *)decryptData:(NSData *)data decryptionKey:(NSData *)key {
    // AES-256 decryption
    // Original function at line 641 in dump
    // CCCrypt call found around line 7020442

    if (!data || !key || key.length != kKeyLength) {
        return nil;
    }

    size_t bufferSize = data.length + kCCBlockSizeAES128;
    NSMutableData *decryptedData = [NSMutableData dataWithLength:bufferSize];

    size_t numBytesDecrypted = 0;

    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kKeyLength,
                                     NULL,  // No IV (ECB mode)
                                     data.bytes,
                                     data.length,
                                     decryptedData.mutableBytes,
                                     bufferSize,
                                     &numBytesDecrypted);

    if (status == kCCSuccess) {
        decryptedData.length = numBytesDecrypted;
        return [decryptedData copy];
    }

    return nil;
}

#pragma mark - Instance Methods

- (NSData *)encryptData:(NSData *)data encryptionKey:(NSData *)key {
    // AES-256 encryption
    // Original function at line 426 in dump
    // CCCrypt call found around line 7035498

    if (!data || !key || key.length != kKeyLength) {
        return nil;
    }

    size_t bufferSize = data.length + kCCBlockSizeAES128;
    NSMutableData *encryptedData = [NSMutableData dataWithLength:bufferSize];

    size_t numBytesEncrypted = 0;

    CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kKeyLength,
                                     NULL,  // No IV (ECB mode)
                                     data.bytes,
                                     data.length,
                                     encryptedData.mutableBytes,
                                     bufferSize,
                                     &numBytesEncrypted);

    if (status == kCCSuccess) {
        encryptedData.length = numBytesEncrypted;
        return [encryptedData copy];
    }

    return nil;
}

- (void)performEncryptionAndDecryption {
    // Test encryption/decryption cycle
    // Original function at line 1062 in dump

    NSString *testPassphrase = @"TestPassphrase";
    NSData *saltData = [kEncryptionSalt dataUsingEncoding:NSUTF8StringEncoding];

    NSData *key = [EncryptionUtility generateKeyFromPassphrase:testPassphrase
                                                          salt:saltData];

    NSString *testString = @"Test data for encryption";
    NSData *originalData = [testString dataUsingEncoding:NSUTF8StringEncoding];

    // Encrypt
    NSData *encryptedData = [self encryptData:originalData encryptionKey:key];

    // Decrypt
    NSData *decryptedData = [EncryptionUtility decryptData:encryptedData
                                             decryptionKey:key];

    NSString *decryptedString = [[NSString alloc] initWithData:decryptedData
                                                      encoding:NSUTF8StringEncoding];

    NSLog(@"Original: %@", testString);
    NSLog(@"Decrypted: %@", decryptedString);
}

@end
