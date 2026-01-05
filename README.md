# T2 SN-Change - Complete Analysis (Change Serial Number on T2 device) (Remove IC lock and MDM)
 
## Executive Summary

This document provides a comprehensive analysis of the `T2 SN-Changer` application, a macOS tool designed to read and modify serial numbers on Apple T2 chip-equipped Macs. The analysis is based on a Hex-Rays decompiled IDA dump of the original binary.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Key Classes and Components](#key-classes-and-components)
4. [Encryption System](#encryption-system)
5. [Serial Number Operations](#serial-number-operations)
6. [String Obfuscation (Hikari)](#string-obfuscation-hikari)
7. [Serial Port Communication](#serial-port-communication)
8. [Data Structures](#data-structures)
9. [Network Features](#network-features)
10. [Security Considerations](#security-considerations)
11. [Reconstructed Code Structure](#reconstructed-code-structure)

---

## Overview

**Application Name:** T2 SN-Changer
**Original Compiler:** GNU C++ (detected by Hex-Rays)
**Target Platform:** macOS (Cocoa framework)
**Obfuscation:** Hikari LLVM-based obfuscation
**Primary Function:** Read/Write serial numbers on T2 Mac devices via serial port communication

### What It Does

1. Connects to a Mac in DFU/Recovery mode via serial port
2. Reads the current serial number from the device
3. Allows modification of the serial number
4. Generates random valid Apple serial numbers
5. Writes new serial numbers to the T2 chip
6. Decrypts diagnostic boot images
7. Logs all serial number changes

---

## Architecture

### Application Structure

```
┌─────────────────────────────────────────────────────────────┐
│                        main.m                                │
│                    (Entry Point)                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     AppDelegate                              │
│              (Application Lifecycle)                         │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    ViewController                            │
│        (Main UI Controller - Serial Number Ops)              │
├─────────────────────────────────────────────────────────────┤
│ • Serial Port Management                                     │
│ • Read/Write Serial Numbers                                  │
│ • Generate Serial Numbers                                    │
│ • Parse/Sanitize Serial Numbers                              │
│ • Decrypt Boot Images                                        │
│ • Logging                                                    │
└─────────────────────────┬───────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
┌─────────────────┐ ┌─────────────┐ ┌─────────────────┐
│EncryptionUtility│ │  Encryption │ │  ORSSerialPort  │
│  (Key Gen/AES)  │ │ (String Enc)│ │  (Serial Comm)  │
└─────────────────┘ └─────────────┘ └─────────────────┘
```

---

## Key Classes and Components

### 1. EncryptionUtility (Lines 13, 224, 426, 641, 1062, 1095)

**Purpose:** Core encryption/decryption operations

| Method | Line | Description |
|--------|------|-------------|
| `+generateRandomBytesWithLength:` | 13 | Generate cryptographically secure random bytes |
| `+generateKeyFromPassphrase:salt:` | 224 | PBKDF2 key derivation |
| `-encryptData:encryptionKey:` | 426 | AES-256 encryption |
| `+decryptData:decryptionKey:` | 641 | AES-256 decryption |
| `-performEncryptionAndDecryption` | 1062 | Test encryption cycle |
| `+initialize` | 1095 | Class initialization |

### 2. Encryption (Lines 26880, 27062, 27308, 27478, 27554)

**Purpose:** High-level encryption interface

| Method | Line | Description |
|--------|------|-------------|
| `+derivedKeyFromPassphrase:salt:iterations:keyLength:` | 26880 | Configurable PBKDF2 |
| `+AES256EncryptData:withKey:` | 27062 | Data encryption |
| `+AES256DecryptData:withKey:` | 27308 | Data decryption |
| `+encryptString:withPassphrase:` | 27478 | String encryption |
| `+decryptString:withPassphrase:` | 27554 | String decryption |

### 3. ViewController (Lines 42577-68914)

**Purpose:** Main UI controller handling all serial number operations

| Method | Line | Description |
|--------|------|-------------|
| `-refreshSerialPort:` | 42577 | Refresh available serial ports |
| `-getSerialNumber` | 45114 | Get current device serial |
| `-writeSN` | 51288 | Write serial number to device |
| `-generateSerialNumber` | 52931 | Generate random serial |
| `-sanitizeSerialNumber:` | 53644 | Clean/validate serial |
| `-parseSerialNumber:` | 54018 | Parse serial components |
| `-decryptBootImageAtPath:` | 56043 | Decrypt boot images |
| `-autoConnectToSerialPort` | 63128 | Auto-connect to port |
| `-formattedSerialNumberFromTextField:` | 64044 | Get formatted serial |
| `-readSerialNumber` | 64445 | Read serial from device |
| `-sendData:` | 64658 | Send data via serial |
| `-decryptedDiagsPath` | 65508 | Get decrypted diags path |

### 4. NSData+AES256 Category (Lines 2164-2785)

**Purpose:** NSData extension for AES encryption

| Method | Line | Description |
|--------|------|-------------|
| `-AES256EncryptWithKey:` | 2164 | Encrypt with key (ECB mode) |
| `-AES256DecryptWithKey:` | 2357 | Decrypt with key (ECB mode) |
| `-AES256EncryptWithKey2:initializationVector:` | 2572 | Encrypt with IV (CBC mode) |
| `-AES256DecryptWithKey2:initializationVector:` | 2785 | Decrypt with IV (CBC mode) |

### 5. ORSSerialPort (Lines 105839-105880)

**Purpose:** Serial port communication (third-party library)

Key methods include:
- `+serialPortWithPath:`
- `-open`
- `-close`
- `-sendData:`
- `-sendRequest:`

---

## Encryption System

### Key Derivation

The application uses **PBKDF2** (Password-Based Key Derivation Function 2) for key generation:

```
Algorithm: PBKDF2-HMAC-SHA1
Iterations: 10,000 (found at line 7309169)
Key Length: 32 bytes (256-bit)
Salt: "ECEJWQXAIFQGCI" (from cfstr_Ecejwqxaifqgci at line 2759275)
```

### AES-256 Encryption

```
Algorithm: AES-256
Mode: ECB (primary) / CBC (with IV)
Padding: PKCS7
Key Size: 32 bytes
Block Size: 16 bytes
```

### Encryption Flow

```
Input String
     │
     ▼
┌────────────────────────────────┐
│ Convert to UTF-8 Data          │
└────────────────┬───────────────┘
                 │
                 ▼
┌────────────────────────────────┐
│ PBKDF2 Key Derivation          │
│ • Passphrase                   │
│ • Salt: "ECEJWQXAIFQGCI"       │
│ • 10,000 iterations            │
│ • Output: 32-byte key          │
└────────────────┬───────────────┘
                 │
                 ▼
┌────────────────────────────────┐
│ AES-256 Encryption             │
│ • PKCS7 Padding                │
│ • ECB/CBC Mode                 │
└────────────────┬───────────────┘
                 │
                 ▼
┌────────────────────────────────┐
│ Base64 Encode                  │
└────────────────┬───────────────┘
                 │
                 ▼
         Encrypted String
```

---

## Serial Number Operations

### Reading Serial Number

1. Connect to device via serial port at 115200 baud
2. Send read command: `serialnumber\r\n`
3. Parse response to extract serial number
4. Store in `oldSerialNumber` property

### Writing Serial Number

1. Get serial number from text field
2. Sanitize (remove invalid chars, uppercase)
3. Log the change
4. Send write command: `setsn <SERIAL_NUMBER>\r\n`

### Serial Number Format

**Modern Apple Serial Numbers (12 characters):**

```
POSITION:  [XX][Y][WW][ZZZ][PPPP]
           │   │  │   │    │
           │   │  │   │    └── Model identifier (4 chars)
           │   │  │   └─────── Unique identifier (3 chars)
           │   │  └─────────── Week of manufacture (2 chars)
           │   └────────────── Year of manufacture (1 char)
           └────────────────── Manufacturing location (2 chars)
```

**Valid Characters:**
- Locations: `CDFGHJKLMNPQRSTVWXYZ`
- General: `0123456789ABCDEFGHJKLMNPQRSTUVWXYZ`

---

## String Obfuscation (Hikari)

The application uses **Hikari** LLVM-based obfuscation to protect strings at compile time.

### How Hikari Works

1. Strings are encrypted at compile time
2. `HikariFunctionWrapper` functions decrypt strings at runtime
3. Each string has a unique wrapper function
4. Decryption happens on first access

### Identified Wrappers

The dump shows **thousands** of `HikariFunctionWrapper_XXXX` functions (lines 1202-99968):

```c
// Example from line 7029395
__int64 __fastcall HikariFunctionWrapper(__int64 a1)
{
    return sub_1000229F0(a1);  // Core decryption routine
}
```

### String Reconstruction at Runtime

Strings are reconstructed using `strcpy` and `qmemcpy` at runtime:

```c
// Example from line 7309238
strcpy(&byte_1008A1A40, "derivedKeyFromPassphrase:salt:iterations:keyLength:");
```

---

## Serial Port Communication

### Configuration

```
Baud Rate: 115200
Data Bits: 8
Stop Bits: 1
Parity: None
Flow Control: None
```

### Protocol

The application communicates with the T2 chip using a text-based protocol:

| Command | Description |
|---------|-------------|
| `serialnumber` | Read current serial number |
| `setsn <SN>` | Set new serial number |

### Connection Flow

```
1. Enumerate available serial ports
2. Select port (manual or auto)
3. Open port at 115200 baud
4. Set delegate for callbacks
5. Send commands
6. Receive and parse responses
7. Close port on disconnect
```

---

## Data Structures

### Global State Variables (Lines 3531598-3531618)

```objc
id MODE_INFO = @"Disconnected";     // Connection status
id ECID_INFO = @"";                  // Exclusive Chip ID
id CPID_INFO = @"";                  // Chip ID
id ProductType = @"";                // Device product type
id SN_INFO = @"";                    // Serial number info
id Support_INFO = @"";               // Support information
id NAME_INFO = @"";                  // Device name

// Hardware info array (7 elements)
__CFString *HW_INFO[7];

// File operation constants
__CFString *FileNameTmp[4] = {
    @"file.tmp",
    @"in_progress",
    @"",
    @"alpine"
};

// Service identifier
id service = @"Activationlock";

// DFU detection flag
BOOL is_detect_dfu_handle_active = YES;
```

### HW_INFO Array Indices

| Index | Purpose |
|-------|---------|
| 0 | ECID |
| 1 | CPID |
| 2 | ProductType |
| 3 | Model |
| 4 | BoardID |
| 5 | ChipID |
| 6 | Reserved |

---

---

## Security Considerations

### Encryption Strength

| Aspect | Rating | Notes |
|--------|--------|-------|
| Algorithm | Strong | AES-256 is industry standard |
| Key Derivation | Good | PBKDF2 with 10,000 iterations |
| Salt | Weak | Hardcoded salt reduces security |
| Mode | ECB (Weak) | ECB mode has known weaknesses |

### Weaknesses Identified

1. **Hardcoded Salt:** The salt `ECEJWQXAIFQGCI` is embedded in the binary
2. **ECB Mode:** Primary encryption uses ECB which doesn't hide patterns
3. **Static Keys:** Encryption keys can be derived from known constants
4. **String Obfuscation Only:** Hikari provides obfuscation, not true encryption

### IOKit Usage

The application uses IOKit to access hardware information:
- `IOServiceGetMatchingService` - Find platform expert
- `IORegistryEntryCreateCFProperty` - Read IOPlatformSerialNumber
- `IOPlatformExpertDevice` - Access T2 chip data

---

## Reconstructed Code Structure

### File Organization

```
Reconstructed/
├── main.m                    # Application entry point
├── AppDelegate.h/m           # Application lifecycle
├── ViewController.h/m        # Main UI controller
├── EncryptionUtility.h/m     # Core encryption
├── Encryption.h/m            # String encryption
└── (requires ORSSerialPort)  # Third-party serial library
```

### Dependencies

1. **Cocoa Framework** - macOS UI
2. **CommonCrypto** - AES/PBKDF2 encryption
3. **Security Framework** - Random byte generation
4. **IOKit** - Hardware access
5. **ORSSerialPort** - Serial communication (third-party)

### Building

```bash
# Requires ORSSerialPort framework
# https://github.com/armadsen/ORSSerialPort

# Link frameworks:
# - Cocoa
# - IOKit
# - Security
# - CommonCrypto (via Security)
```

---

## Conclusion

T2 SN-Changer is a sophisticated macOS application for modifying Apple T2 chip serial numbers. It combines:

- **Serial port communication** for device interaction
- **AES-256 encryption** for data protection
- **PBKDF2 key derivation** for password-based encryption
- **Hikari obfuscation** for string protection

The reconstructed code provides a functionally equivalent implementation based on the IDA dump analysis, suitable for educational and research purposes.

---

## References

- Original IDA dump: `T2SN-Changer.c`
- Hex-Rays Decompiler v9.2.0.250908
- Hikari LLVM Obfuscator
- ORSSerialPort: https://github.com/armadsen/ORSSerialPort
- Apple IOKit Documentation
- CommonCrypto Reference

---

*Analysis completed from IDA dump containing 8,235,000+ lines of decompiled code.*
