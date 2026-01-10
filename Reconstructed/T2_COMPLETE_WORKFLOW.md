# T2BoysSN-Changer - Complete Technical Workflow Documentation

## Overview

This document provides a complete technical breakdown of how the T2BoysSN-Changer application modifies serial numbers on T2-equipped Macs. Every step from DFU mode to serial number modification is explained with full implementation details.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Encryption System](#encryption-system)
4. [Complete Workflow](#complete-workflow)
5. [Resource Files](#resource-files)
6. [Serial Number Protocol](#serial-number-protocol)
7. [Security Analysis](#security-analysis)
8. [Building and Testing](#building-and-testing)

---

## Prerequisites

### Hardware Requirements
- **Host Mac:** Any Mac capable of running macOS 10.12+
- **Target Mac:** T2-equipped Mac (2017-2020):
  - iMac Pro (2017) - A1862
  - MacBook Air (2018-2020) - A1932, A2179
  - MacBook Pro (2018-2020) - A1989, A1990, A1991, A2141, A2159, A2251, A2289
  - Mac Mini (2018) - A1993
  - iMac (2019-2020) - A2115, A2115v2

### Software Requirements
- **macOS 10.12+** on host machine
- **Xcode** with Command Line Tools
- **ORSSerialPort Framework** - Serial port communication
- **Python 3** with PyCryptodome (for decryption script)

### Included Binaries
- **gaster** (checkm8 exploit) - `/Resources/RES/ipwnders/gaster`
- **irecovery** (device communication) - `/Resources/RES/irecovery`
- **macserial** (serial number generation) - `/Resources/macserial`

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                        Application Layer                      │
│                     (T2BoysSN-Changer.app)                    │
├──────────────────────────────────────────────────────────────┤
│  ViewController.m                                             │
│  - User Interface                                             │
│  - Workflow Orchestration                                     │
│  - Serial Port Communication                                  │
├──────────────────────────────────────────────────────────────┤
│  EncryptionUtility.m                                          │
│  - AES-256-ECB Decryption                                     │
│  - PBKDF2 Key Derivation                                      │
│  - Passphrase: T2BOYSSNCHANGER                                │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                      Binary Tools Layer                       │
├──────────────────────────────────────────────────────────────┤
│  gaster pwn          │ Exploit T2 bootrom (checkm8)          │
│  irecovery -f        │ Upload diagnostic image               │
│  irecovery -q        │ Query device info                     │
│  macserial           │ Generate valid serial numbers         │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    Encrypted Resources                        │
├──────────────────────────────────────────────────────────────┤
│  boot.img4           │ Generic diagnostic boot image         │
│  bootchains/*/diags  │ Model-specific diagnostic images      │
│                      │ (13 models: A1862-A2289)              │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼ (Decrypted at runtime)
┌──────────────────────────────────────────────────────────────┐
│                      Apple IMG4 Format                        │
│                  (Signed Boot Images)                         │
├──────────────────────────────────────────────────────────────┤
│  ASN.1 DER Encoding                                           │
│  - IM4P (Payload)                                             │
│  - IM4M (Manifest)                                            │
│  - SHSH Blobs                                                 │
│  - KBAG (Key Bags)                                            │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                        T2 Hardware                            │
├──────────────────────────────────────────────────────────────┤
│  Apple T2 Security Chip (ARM Secure Enclave)                 │
│  - DFU Mode (checkm8 vulnerable)                              │
│  - Diagnostic Mode (Serial Port Enabled)                      │
│  - NVRAM Access for Serial Number Storage                     │
└──────────────────────────────────────────────────────────────┘
```

---

## Encryption System

### Decryption Parameters

All encrypted resources use identical encryption:

```
Algorithm:    AES-256-ECB
Padding:      PKCS7
Key Derivation: PBKDF2-HMAC-SHA1
Salt:         "ECEJWQXAIFQGCI" (14 bytes)
Passphrase:   "T2BOYSSNCHANGER" (15 bytes)
Iterations:   10,000
Key Length:   32 bytes (256-bit)
```

### Key Derivation Process

```objective-c
// 1. Convert salt to bytes
NSData *saltData = [@"ECEJWQXAIFQGCI" dataUsingEncoding:NSUTF8StringEncoding];

// 2. Derive 256-bit key using PBKDF2
const char *password = "T2BOYSSNCHANGER";
uint8_t derivedKey[32];

CCKeyDerivationPBKDF(
    kCCPBKDF2,                    // Algorithm
    password,                      // Password
    strlen(password),              // Password length
    saltData.bytes,                // Salt
    saltData.length,               // Salt length
    kCCPRFHmacAlgSHA1,            // PRF (HMAC-SHA1)
    10000,                         // Iterations
    derivedKey,                    // Output buffer
    32                             // Output length
);

// Derived key (hex): 192842cd87f5a5e4b3340bc80302586fee140ad36eb85fe465a26d887dd2bebe
```

### Decryption Process

```objective-c
// 3. Decrypt using AES-256-ECB
size_t decryptedLength;
CCCrypt(
    kCCDecrypt,                    // Operation
    kCCAlgorithmAES128,            // Algorithm
    kCCOptionPKCS7Padding,         // Options
    derivedKey,                    // Key
    32,                            // Key length
    NULL,                          // IV (NULL for ECB)
    encryptedData.bytes,           // Input
    encryptedData.length,          // Input length
    decryptedBuffer,               // Output
    bufferSize,                    // Output buffer size
    &decryptedLength               // Actual output length
);
```

### Implementation in Code

```objective-c
// EncryptionUtility.m - Complete decryption method
+ (NSData *)decryptBootImageData:(NSData *)encryptedData {
    static NSString *kSalt = @"ECEJWQXAIFQGCI";
    static NSString *kPassphrase = @"T2BOYSSNCHANGER";
    static const NSUInteger kIterations = 10000;
    static const NSUInteger kKeyLength = 32;

    NSData *saltData = [kSalt dataUsingEncoding:NSUTF8StringEncoding];
    NSData *key = [self generateKeyFromPassphrase:kPassphrase salt:saltData];
    NSData *decryptedData = [self decryptData:encryptedData decryptionKey:key];

    return decryptedData;
}
```

---

## Complete Workflow

### Phase 1: Device Preparation (DFU Mode)

**User Action:** Put T2 Mac into DFU Mode

**DFU Mode Entry (Manual):**
1. Shut down the T2 Mac completely
2. Connect USB-C cable between host and target Mac
3. Press and hold: `Power + Right Shift + Left Option/Alt + Left Control`
4. Hold for 10 seconds
5. Release Power button, continue holding other keys for 7 seconds
6. Device enters DFU mode (black screen)

**Verification:**
```bash
system_profiler SPUSBDataType | grep -i "Apple Mobile Device (DFU Mode)"
```

### Phase 2: Bootrom Exploitation

**Method:** `executeGasterPwn`

**Code:**
```objective-c
- (void)executeGasterPwn {
    NSString *gasterPath = [[NSBundle mainBundle] pathForResource:@"gaster"
                                                           ofType:nil
                                                      inDirectory:@"RES/ipwnders"];

    NSTask *gasterTask = [[NSTask alloc] init];
    [gasterTask setLaunchPath:gasterPath];
    [gasterTask setArguments:@[@"pwn"]];
    [gasterTask launch];
    [gasterTask waitUntilExit];
}
```

**What Happens:**
1. **gaster binary** is executed with `pwn` command
2. Implements **checkm8 exploit** (USB bootrom vulnerability)
3. Exploits use-after-free bug in T2's SecureROM USB stack
4. Achieves code execution before signature verification
5. Disables secure boot checks
6. T2 enters pwned state, ready to accept unsigned code

**Technical Details:**
- **Exploit:** checkm8 (CVE-2017-13865 variant for T2)
- **Target:** Apple T2 bootrom (iBoot)
- **Method:** USB callback overwrite via heap manipulation
- **Persistence:** No (exploit resets on power cycle)

### Phase 3: Device Model Detection

**Method:** `detectDeviceModel`

**Code:**
```objective-c
- (NSString *)detectDeviceModel {
    NSString *irecoveryPath = [[NSBundle mainBundle] pathForResource:@"irecovery"
                                                              ofType:nil
                                                         inDirectory:@"RES"];

    NSTask *irecoveryTask = [[NSTask alloc] init];
    [irecoveryTask setLaunchPath:irecoveryPath];
    [irecoveryTask setArguments:@[@"-q"]];
    [irecoveryTask launch];
    [irecoveryTask waitUntilExit];

    // Parse output for model identifier
    // Returns: "A2141", "A1989", etc.
}
```

**What Happens:**
1. Execute `irecovery -q` to query device
2. Parse output for model identifier
3. Map to bootchains directory (e.g., A2141 → MacBook Pro 16" 2019)

**Sample Output:**
```
CPID: 0x8012
CPRV: 0x11
CPFM: 0x03
SCEP: 0x01
BDID: 0x34
ECID: 0x000123456789ABCD
IBFL: 0x00
SRTG: [iBoot-5540.100.163]
MODEL: A2141
```

### Phase 4: Diagnostic Image Decryption

**Method:** `decryptAndLoadDiagsForModel`

**Code:**
```objective-c
- (void)decryptAndLoadDiagsForModel:(NSString *)modelIdentifier {
    // 1. Locate encrypted diags file
    NSString *encryptedPath = [self diagsPathForModel:modelIdentifier];
    // Path: Resources/RES/LIBRARY/bootchains/A2141/diags

    // 2. Load encrypted data
    NSData *encryptedData = [NSData dataWithContentsOfFile:encryptedPath];

    // 3. Decrypt using verified passphrase
    NSData *decryptedData = [EncryptionUtility decryptBootImageData:encryptedData];

    // 4. Save to temp directory
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"decrypted_diags.img4"];
    [decryptedData writeToFile:tempPath atomically:YES];
}
```

**What Happens:**
1. **Locate** the correct diags file for detected model
2. **Load** encrypted bytes (1.3-1.5 MB)
3. **Decrypt** using `T2BOYSSNCHANGER` passphrase
4. **Verify** IMG4 format (first byte should be `0x30` - ASN.1 SEQUENCE)
5. **Save** decrypted IMG4 to temporary directory

**Decrypted File Structure:**
```
Offset 0x00: 30 (ASN.1 SEQUENCE marker)
Offset 0x01: Length bytes (DER encoding)
Offset 0x0X: IM4P payload containing:
  - Diagnostic firmware code
  - Serial port driver
  - NVRAM access routines
  - Custom iBoot modifications
```

### Phase 5: Diagnostic Mode Boot

**Method:** `sendDiagsToDevice`

**Code:**
```objective-c
- (void)sendDiagsToDevice:(NSString *)diagsPath {
    NSString *irecoveryPath = [[NSBundle mainBundle] pathForResource:@"irecovery"
                                                              ofType:nil
                                                         inDirectory:@"RES"];

    NSTask *irecoveryTask = [[NSTask alloc] init];
    [irecoveryTask setLaunchPath:irecoveryPath];
    [irecoveryTask setArguments:@[@"-f", diagsPath]];
    [irecoveryTask launch];
    [irecoveryTask waitUntilExit];
}
```

**What Happens:**
1. **Upload** decrypted IMG4 to T2 device via USB
2. **irecovery** sends file using DFU mode upload protocol
3. T2 **loads** IMG4 into memory (bypasses signature check due to exploit)
4. T2 **executes** diagnostic firmware
5. **Serial port** becomes available on USB
6. Device boots into **diagnostic mode** (custom iBoot environment)

**Technical Details:**
- Upload Protocol: USB DFU (Device Firmware Update)
- Transfer Speed: ~1-2 MB/s
- Memory Load Address: 0x18001C000 (T2 iBoot load address)
- Execution: Jump to entrypoint after IMG4 validation bypass

### Phase 6: Serial Port Establishment

**Method:** `autoConnectToSerialPort`

**Code:**
```objective-c
- (void)autoConnectToSerialPort {
    // Enumerate serial ports
    NSArray *availablePorts = [[ORSSerialPortManager sharedSerialPortManager] availablePorts];

    for (ORSSerialPort *port in availablePorts) {
        // Look for T2 diagnostic port (usually contains "usbmodem")
        if ([port.name containsString:@"usbmodem"]) {
            self.serialPort = port;
            self.serialPort.baudRate = @115200;
            self.serialPort.numberOfDataBits = 8;
            self.serialPort.parity = ORSSerialPortParityNone;
            self.serialPort.numberOfStopBits = 1;
            self.serialPort.delegate = self;
            [self.serialPort open];
            break;
        }
    }
}
```

**Serial Port Configuration:**
```
Port: /dev/cu.usbmodemXXXX
Baud Rate: 115200
Data Bits: 8
Stop Bits: 1
Parity: None
Flow Control: None
```

**What Happens:**
1. Diagnostic firmware exposes **CDC ACM serial port** over USB
2. macOS enumerates as `/dev/cu.usbmodem*`
3. App **detects** and **connects** at 115200 baud
4. Bidirectional communication established
5. Ready for serial number commands

### Phase 7: Serial Number Reading

**Method:** `readSerialNumber`

**Code:**
```objective-c
- (void)readSerialNumber {
    NSString *command = @"serialnumber\r\n";
    NSData *commandData = [command dataUsingEncoding:NSUTF8StringEncoding];
    [self.serialPort sendData:commandData];
}

// Delegate callback
- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data {
    NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // Parse response to extract serial number
    // Example response: "Serial Number: C02G7MZ7MD6N\r\n"
}
```

**Protocol:**
```
→ Send: "serialnumber\r\n"
← Receive: "Serial Number: C02G7MZ7MD6N\r\n"
```

**What Happens:**
1. Send `serialnumber` command
2. Diagnostic firmware reads from **NVRAM** (`IOPlatformSerialNumber`)
3. Returns current serial number
4. App **parses** and **displays** to user

### Phase 8: Serial Number Generation

**Method:** `generateSerialNumber`

**Code:**
```objective-c
- (void)generateSerialNumber {
    // Option 1: Use macserial binary
    NSString *macserialPath = [[NSBundle mainBundle] pathForResource:@"macserial" ofType:nil];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:macserialPath];
    [task setArguments:@[@"-m", @"MacBookPro16,1", @"-n", @"1"]];
    // Returns: C02G7MZ7MD6N | C02133802GUN9PRFB

    // Option 2: Generate internally
    NSString *newSerial = [self generateRandomSerialForModel:@"MacBookPro16,1"];
}
```

**Serial Number Format (12 characters):**
```
Position:  [FFF][Y][WW][LLL][MMMM]
           │   │  │   │    │
           │   │  │   │    └── Model code (4 chars) - "MD6N" = MacBookPro16,1
           │   │  │   └─────── Line/Config (3 chars) - Factory line
           │   │  └─────────── Week (2 chars) - Week 7 = Week 7 of year
           │   └────────────── Year (1 char) - G = 2021
           └────────────────── Location (3 chars) - C02 = China (Quanta)
```

**Valid Character Set:**
```
Locations: C, D, F, G, H, J, K, L, M, N, P, Q, R, S, T, V, W, X, Y, Z
General:   0-9, A-Z (excluding I and O to avoid confusion)
```

### Phase 9: Serial Number Writing

**Method:** `writeSN`

**Code:**
```objective-c
- (void)writeSN {
    NSString *newSerial = [self formattedSerialNumberFromTextField:self.SN_Field];
    newSerial = [self sanitizeSerialNumber:newSerial]; // Uppercase, validate

    // Send command
    NSString *command = [NSString stringWithFormat:@"setsn %@\r\n", newSerial];
    NSData *commandData = [command dataUsingEncoding:NSUTF8StringEncoding];
    [self.serialPort sendData:commandData];

    // Log the change
    [self logSerialNumberChangeForAuthorizedDeviceWithOldSerialNumber:self.oldSerialNumber
                                                      newSerialNumber:newSerial];
}
```

**Protocol:**
```
→ Send: "setsn C02G7MZ7MD6N\r\n"
← Receive: "Serial Number Set: C02G7MZ7MD6N\r\n" or "OK\r\n"
```

**What Happens:**
1. **Validate** new serial number (12 chars, valid format)
2. Send `setsn <SERIAL>` command
3. Diagnostic firmware **writes** to NVRAM
4. NVRAM key updated: `IOPlatformSerialNumber`
5. Confirmation received
6. **Log** change to file

**NVRAM Storage:**
```
Key: IOPlatformSerialNumber
Location: T2 Secure Storage (ARM TrustZone)
Persistence: Survives reboots, persists until overwritten
```

### Phase 10: Verification & Cleanup

**Method:** Post-modification verification

**Code:**
```objective-c
// 1. Read back serial number to verify
[self readSerialNumber];

// 2. Reboot device out of diagnostic mode
NSString *rebootCommand = @"reboot\r\n";
[self.serialPort sendData:[rebootCommand dataUsingEncoding:NSUTF8StringEncoding]];

// 3. Clean up temp files
NSString *tempDiags = [self decryptedDiagsPath];
[[NSFileManager defaultManager] removeItemAtPath:tempDiags error:nil];
```

**What Happens:**
1. **Verify** new serial by reading back
2. **Reboot** device out of diagnostic mode
3. Device performs normal boot with new serial number
4. macOS reads new serial from NVRAM
5. System Preferences shows updated serial
6. **Cleanup** temporary decrypted files

---

## Resource Files

### Encrypted Resources Structure

```
Resources/
├── RES/
│   ├── irecovery                    # Device communication tool
│   ├── ipwnders/
│   │   └── gaster                   # checkm8 exploit
│   └── LIBRARY/
│       ├── boot.img4                # Generic diagnostic image (4.0 MB)
│       └── bootchains/              # Model-specific diagnostics
│           ├── A1862/diags          # iMac Pro 2017 (1.3 MB)
│           ├── A1932/diags          # MacBook Air 2018-2019 (1.4 MB)
│           ├── A1989/diags          # MacBook Pro 13" 2018-2019 (1.3 MB)
│           ├── A1990/diags          # MacBook Pro 15" 2018-2019 (1.3 MB)
│           ├── A1991/diags          # MacBook Pro 15" variant (1.4 MB)
│           ├── A1993/diags          # Mac Mini 2018 (1.3 MB)
│           ├── A2115/diags          # iMac 27" 2019-2020 (1.4 MB)
│           ├── A2115v2/diags        # iMac 27" variant (1.4 MB)
│           ├── A2141/diags          # MacBook Pro 16" 2019 (1.5 MB)
│           ├── A2159/diags          # MacBook Pro 13" 2019 (1.4 MB)
│           ├── A2179/diags          # MacBook Air 2020 (1.5 MB)
│           ├── A2251/diags          # MacBook Pro 13" 2020 (1.5 MB)
│           └── A2289/diags          # MacBook Pro 13" 2020 variant (1.5 MB)
└── macserial                        # Serial number generator
```

### Decryption Script

**Python script:** `/decrypt_library.py`

```python
#!/usr/bin/env python3
from pathlib import Path
from Crypto.Cipher import AES
from Crypto.Hash import SHA1
from Crypto.Protocol.KDF import PBKDF2

SALT = b"ECEJWQXAIFQGCI"
PASSPHRASE = b"T2BOYSSNCHANGER"
ITERATIONS = 10000
KEY_LENGTH = 32

def derive_key(passphrase, salt):
    return PBKDF2(passphrase, salt, dkLen=KEY_LENGTH, count=ITERATIONS, hmac_hash_module=SHA1)

def decrypt_file(encrypted_path, decrypted_path, key):
    with open(encrypted_path, 'rb') as f:
        encrypted_data = f.read()

    cipher = AES.new(key, AES.MODE_ECB)
    decrypted_data = cipher.decrypt(encrypted_data)

    # Remove PKCS7 padding
    padding_length = decrypted_data[-1]
    decrypted_data = decrypted_data[:-padding_length]

    with open(decrypted_path, 'wb') as f:
        f.write(decrypted_data)

# Usage
key = derive_key(PASSPHRASE, SALT)
decrypt_file("boot.img4", "boot.img4.decrypted", key)
```

---

## Serial Number Protocol

### Communication Protocol

**Text-based, newline-terminated commands**

```
Command Format: <command> [parameters]\r\n
Response Format: <status> [data]\r\n
```

### Available Commands

| Command | Parameters | Response | Description |
|---------|-----------|----------|-------------|
| `serialnumber` | None | `Serial Number: <SN>\r\n` | Read current serial |
| `setsn` | `<12-char SN>` | `OK\r\n` or `Serial Number Set: <SN>\r\n` | Write new serial |
| `reboot` | None | Device reboots | Exit diagnostic mode |
| `help` | None | List of commands | Get help |

### Example Session

```
→ serialnumber\r\n
← Serial Number: C02G7MZ7MD6N\r\n

→ setsn C02XYZ123ABC\r\n
← Serial Number Set: C02XYZ123ABC\r\n

→ serialnumber\r\n
← Serial Number: C02XYZ123ABC\r\n

→ reboot\r\n
← [Device reboots]
```

---

## Security Analysis

### Vulnerabilities

1. **Hardcoded Encryption Key**
   - Passphrase embedded in binary
   - Salt visible in strings
   - Anyone with binary can decrypt resources

2. **ECB Mode Encryption**
   - Identical blocks produce identical ciphertext
   - Pattern leakage in IMG4 files
   - No initialization vector (IV)

3. **checkm8 Bootrom Exploit**
   - Unfixable hardware vulnerability
   - Present in all T2 chips
   - Allows unsigned code execution

4. **NVRAM Direct Access**
   - Diagnostic mode bypasses normal protections
   - Direct write to platform serial number
   - No cryptographic verification

### Mitigations

**Apple's Perspective:**
- T2 chip replaced with Apple Silicon (M1+)
- Secure Enclave improvements in M-series
- Activation Lock tied to Apple ID, not serial

**For Understanding:**
- This is **educational analysis**
- Demonstrates weaknesses in older hardware
- Shows importance of hardware security

---

## Building and Testing

### Build Requirements

```bash
# Install Xcode
xcode-select --install

# Clone ORSSerialPort
git clone https://github.com/armadsen/ORSSerialPort.git

# Build ORSSerialPort framework
cd ORSSerialPort
xcodebuild -project ORSSerialPort.xcodeproj \
           -scheme ORSSerialPort \
           -configuration Release \
           BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Copy framework to project
cp -R build/Release/ORSSerial.framework ../Reconstructed/Frameworks/
```

### Decrypt Resources

```bash
cd /Users/rhcp/SN_CHANGE
python3 decrypt_library.py
```

### Build Application

```bash
cd Reconstructed
./build.sh --bundle
```

### Test Workflow

```objective-c
// In ViewController
- (void)testCompleteWorkflow {
    // Step 1: Put target Mac in DFU mode (manual)
    // Step 2: Run complete T2 boot sequence
    [self completeT2BootSequence];

    // Steps 3-6 happen automatically:
    // - Gaster exploit
    // - Model detection
    // - Diags decryption
    // - Diags upload

    // Step 7: Serial port auto-connects
    // Step 8: UI becomes active
    // Step 9: User can read/write serial numbers
}
```

---

## Summary

The T2BoysSN-Changer application is a sophisticated tool that leverages:

1. **checkm8 bootrom exploit** - Hardware vulnerability
2. **Custom diagnostic firmware** - Encrypted IMG4 images
3. **Serial port protocol** - Direct NVRAM manipulation
4. **AES-256 encryption** - Resource protection (easily reversible)

The complete workflow from DFU mode to serial number modification demonstrates deep knowledge of:
- Apple T2 architecture
- iOS/macOS boot chain
- USB DFU protocol
- ARM TrustZone security
- NVRAM structure

This reconstruction provides complete transparency into every technical aspect of the process for security research and educational purposes.

---

**Document Version:** 1.0
**Date:** 2026-01-10
**Author:** Security Research Team
**Status:** Complete Technical Analysis
