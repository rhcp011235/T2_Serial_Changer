//
//  Encryption.m
//  TheT2BoysSN-Changer
//
//  Reconstructed from IDA dump
//

#import "Encryption.h"
#import <CommonCrypto/CommonCrypto.h>

// Salt used for string encryption (from cfstr_Ecejwqxaifqgci)
static NSString * const kEncryptionSalt = @"ECEJWQXAIFQGCI";
static const NSUInteger kDefaultIterations = 10000;
static const NSUInteger kDefaultKeyLength = 32;

@implementation Encryption

#pragma mark - Key Derivation

+ (NSData *)derivedKeyFromPassphrase:(NSString *)passphrase
                                salt:(NSData *)salt
                          iterations:(NSUInteger)iterations
                           keyLength:(NSUInteger)keyLength {
    // PBKDF2 key derivation
    // Original function at line 26880 in dump
    // Implementation found around line 7298975

    if (!passphrase || !salt) {
        return nil;
    }

    NSMutableData *derivedKey = [NSMutableData dataWithLength:keyLength];

    const char *passwordBytes = [passphrase UTF8String];
    size_t passwordLength = strlen(passwordBytes);

    int result = CCKeyDerivationPBKDF(kCCPBKDF2,
                                      passwordBytes,
                                      passwordLength,
                                      salt.bytes,
                                      salt.length,
                                      kCCPRFHmacAlgSHA1,
                                      (uint)iterations,
                                      derivedKey.mutableBytes,
                                      keyLength);

    if (result == kCCSuccess) {
        return [derivedKey copy];
    }

    return nil;
}

#pragma mark - AES-256 Data Encryption/Decryption

+ (NSData *)AES256EncryptData:(NSData *)data withKey:(NSData *)key {
    // Original function at line 27062 in dump
    // Implementation around line 7302280

    if (!data || !key || key.length < kCCKeySizeAES256) {
        return nil;
    }

    return [data AES256EncryptWithKey:key];
}

+ (NSData *)AES256DecryptData:(NSData *)data withKey:(NSData *)key {
    // Original function at line 27308 in dump
    // Implementation around line 7306194

    if (!data || !key || key.length < kCCKeySizeAES256) {
        return nil;
    }

    return [data AES256DecryptWithKey:key];
}

#pragma mark - String Encryption/Decryption

+ (NSString *)encryptString:(NSString *)string withPassphrase:(NSString *)passphrase {
    // Encrypt string using passphrase
    // Original function at line 27478 in dump
    // Implementation around line 7309104

    if (!string || !passphrase) {
        return nil;
    }

    // Get salt data
    NSData *saltData = [kEncryptionSalt dataUsingEncoding:NSUTF8StringEncoding];

    // Derive key from passphrase
    NSData *key = [self derivedKeyFromPassphrase:passphrase
                                            salt:saltData
                                      iterations:kDefaultIterations
                                       keyLength:kDefaultKeyLength];

    // Convert string to data
    NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];

    // Encrypt
    NSData *encryptedData = [self AES256EncryptData:stringData withKey:key];

    // Encode to base64 for storage
    NSString *base64String = [encryptedData base64EncodedStringWithOptions:0];

    return base64String;
}

+ (NSString *)decryptString:(NSString *)encryptedString withPassphrase:(NSString *)passphrase {
    // Decrypt string using passphrase
    // Original function at line 27554 in dump
    // Implementation around line 7310489

    if (!encryptedString || !passphrase) {
        return nil;
    }

    // Get salt data
    NSData *saltData = [kEncryptionSalt dataUsingEncoding:NSUTF8StringEncoding];

    // Derive key from passphrase
    NSData *key = [self derivedKeyFromPassphrase:passphrase
                                            salt:saltData
                                      iterations:kDefaultIterations
                                       keyLength:kDefaultKeyLength];

    // Decode from base64
    NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:encryptedString
                                                                options:0];

    // Decrypt
    NSData *decryptedData = [self AES256DecryptData:encryptedData withKey:key];

    if (!decryptedData) {
        return nil;
    }

    // Convert to string
    NSString *decryptedString = [[NSString alloc] initWithData:decryptedData
                                                      encoding:NSUTF8StringEncoding];

    return decryptedString;
}

@end

#pragma mark - NSData AES256 Category

@implementation NSData (AES256)

- (NSData *)AES256EncryptWithKey:(NSData *)key {
    // Original function at line 2164 in dump
    // Implementation around line 7035190

    if (!key || key.length < kCCKeySizeAES256) {
        return nil;
    }

    size_t bufferSize = self.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);

    if (!buffer) {
        return nil;
    }

    size_t numBytesEncrypted = 0;

    CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kCCKeySizeAES256,
                                     NULL,  // ECB mode - no IV
                                     self.bytes,
                                     self.length,
                                     buffer,
                                     bufferSize,
                                     &numBytesEncrypted);

    if (status == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted freeWhenDone:YES];
    }

    free(buffer);
    return nil;
}

- (NSData *)AES256DecryptWithKey:(NSData *)key {
    // Original function at line 2357 in dump
    // Implementation around line 7038303

    if (!key || key.length < kCCKeySizeAES256) {
        return nil;
    }

    size_t bufferSize = self.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);

    if (!buffer) {
        return nil;
    }

    size_t numBytesDecrypted = 0;

    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kCCKeySizeAES256,
                                     NULL,  // ECB mode - no IV
                                     self.bytes,
                                     self.length,
                                     buffer,
                                     bufferSize,
                                     &numBytesDecrypted);

    if (status == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted freeWhenDone:YES];
    }

    free(buffer);
    return nil;
}

- (NSData *)AES256EncryptWithKey2:(NSData *)key initializationVector:(NSData *)iv {
    // Original function at line 2572 in dump
    // Implementation around line 7041676

    if (!key || key.length < kCCKeySizeAES256) {
        return nil;
    }

    size_t bufferSize = self.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);

    if (!buffer) {
        return nil;
    }

    size_t numBytesEncrypted = 0;

    CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kCCKeySizeAES256,
                                     iv ? iv.bytes : NULL,
                                     self.bytes,
                                     self.length,
                                     buffer,
                                     bufferSize,
                                     &numBytesEncrypted);

    if (status == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted freeWhenDone:YES];
    }

    free(buffer);
    return nil;
}

- (NSData *)AES256DecryptWithKey2:(NSData *)key initializationVector:(NSData *)iv {
    // Original function at line 2785 in dump
    // Implementation around line 7045107

    if (!key || key.length < kCCKeySizeAES256) {
        return nil;
    }

    size_t bufferSize = self.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);

    if (!buffer) {
        return nil;
    }

    size_t numBytesDecrypted = 0;

    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kCCKeySizeAES256,
                                     iv ? iv.bytes : NULL,
                                     self.bytes,
                                     self.length,
                                     buffer,
                                     bufferSize,
                                     &numBytesDecrypted);

    if (status == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted freeWhenDone:YES];
    }

    free(buffer);
    return nil;
}

@end
