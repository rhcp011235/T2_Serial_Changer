# Resources Folder Analysis - T2BoysSN-Changer

## Overview

This document analyzes how the Resources folder contents are used by the T2BoysSN-Changer application based on the IDA dump reconstruction.

---

## Resource Structure

```
Resources/
├── AppIcon.icns              # Application icon (117KB)
├── Assets.car                # Compiled asset catalog (2.2MB)
├── macserial                 # Serial number generation tool (495KB, x86_64)
├── Main.storyboardc/         # Compiled storyboard UI
│   ├── 5gI-5U-AMq-view-ERx-hH-rdd.nib   # Main view controller NIB
│   ├── Document Window Controller.nib    # Window controller
│   ├── Info.plist                         # Storyboard metadata
│   └── MainMenu.nib                       # Menu bar
└── RES/
    ├── irecovery             # Recovery mode communication tool (77KB, x86_64)
    ├── ipwnders/
    │   └── gaster            # DFU exploit tool (53KB, x86_64)
    └── LIBRARY/
        ├── boot.img4         # Encrypted boot image (4.2MB)
        └── bootchains/       # Model-specific encrypted diagnostics
            ├── A1862/diags   # iMac Pro (1.3MB)
            ├── A1932/diags   # MacBook Air 2018-2019 (1.4MB)
            ├── A1989/diags   # MacBook Pro 13" 2018-2019 (1.3MB)
            ├── A1990/diags   # MacBook Pro 15" 2018-2019 (1.4MB)
            ├── A1991/diags   # MacBook Pro 15" 2018-2019 variant (1.5MB)
            ├── A1993/diags   # Mac Mini 2018 (1.3MB)
            ├── A2115/diags   # iMac 27" 2019-2020 (1.5MB)
            ├── A2115v2/diags # iMac 27" variant (1.5MB)
            ├── A2141/diags   # MacBook Pro 16" 2019 (1.5MB)
            ├── A2159/diags   # MacBook Pro 13" 2019 (1.4MB)
            ├── A2179/diags   # MacBook Air 2020 (1.5MB)
            ├── A2251/diags   # MacBook Pro 13" 2020 (1.5MB)
            └── A2289/diags   # MacBook Pro 13" 2020 variant (1.5MB)
```

---

## Resource Usage Analysis

### 1. AppIcon.icns

**Purpose:** Application icon displayed in Dock, Finder, and About window.

**Integration:** Referenced in `Info.plist`:
```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

---

### 2. Main.storyboardc

**Purpose:** Compiled storyboard containing the entire UI layout.

**Contents:**
- `MainMenu.nib` - Application menu bar
- `Document Window Controller.nib` - Main window controller
- `5gI-5U-AMq-view-ERx-hH-rdd.nib` - ViewController's view hierarchy

**UI Elements (from ViewController.h):**
- `WriteSN_BTN` - Write serial number button
- `SN_Field` - Serial number text field
- `SN_Field_DIAG` - Diagnostic serial field
- `serialConnectBTN` - Connect/disconnect button
- `WriteNewSerialNumber` - Additional write button
- `serialPortPopup` - Serial port dropdown
- `statusLabel` - Status display label
- `progressIndicator` - Activity indicator

**Integration:** Referenced in `Info.plist`:
```xml
<key>NSMainStoryboardFile</key>
<string>Main</string>
```

---

### 3. macserial (Open Source)

**Purpose:** Generates and validates Apple serial numbers.

**Origin:** Acidanthera OpenCorePkg project (BSD 3-Clause License)

**Repository:** https://github.com/acidanthera/OpenCorePkg

**Source Location:** `OpenCorePkg/Utilities/macserial/`

**Version in Bundle:** 2.1.8 ("ugrobator")

**Build from Source:**
```bash
git clone https://github.com/acidanthera/OpenCorePkg.git
cd OpenCorePkg/Utilities/macserial
make
```

**Source Files:**
| File | Description |
|------|-------------|
| `macserial.c` | Main program (~2000 lines) |
| `macserial.h` | Header definitions |
| `modelinfo.h` | Apple model database (all Mac models, codes, years) |
| `modelinfo_autogen.h` | Auto-generated model data |

**Command Line Options:**
```
Arguments:
  --help           (-h)  show help
  --version        (-v)  show program version
  --deriv <serial> (-d)  generate all derivative serials
  --generate       (-g)  generate serial for current model
  --generate-all   (-a)  generate serial for all models
  --info <serial>  (-i)  decode serial information
  --verify <mlb>         verify MLB checksum
  --list           (-l)  list known mac models
  --list-products  (-lp) list known product codes
  --mlb <serial>         generate MLB based on serial
  --sys            (-s)  get system info

Tuning options:
  --model <model>  (-m)  mac model used for generation
  --num <num>      (-n)  number of generated pairs
  --year <year>    (-y)  year used for generation
  --week <week>    (-w)  week used for generation
  --country <loc>  (-c)  country location used for generation
  --copy <copy>    (-o)  production copy index
  --line <line>    (-e)  production line
  --platform <ppp> (-p)  platform code used for generation
```

**Example Usage:**
```bash
# Generate serial for MacBook Pro 16"
./macserial -m "MacBookPro16,1" -n 1
# Output: C02G7MZ7MD6N | C02133802GUN9PRFB
#         (Serial)       (MLB)

# Decode a serial number
./macserial -i "C02G7MZ7MD6N"
# Output:
#    Country:  C02 - China (Quanta Computer)
#       Year:    G - 2021
#       Week:    7 - 33 (13.08.2021-19.08.2021)
#       Line:  MZ7 - 2557 (copy 1)
#      Model: MD6N - MacBookPro16,1
# SystemModel: MacBook Pro (16-inch, 2019)
#      Valid: Possibly

# List all supported models
./macserial -l
```

**Serial Number Format (12-character modern format):**
```
Position:  [PPP][Y][W][W][LLL][CCCC]
            │    │  │ │  │    │
            │    │  │ │  │    └── Model code (4 chars)
            │    │  │ │  └─────── Production line (3 chars)
            │    │  └─┴────────── Week of manufacture (2 chars)
            │    └─────────────── Year of manufacture (1 char)
            └──────────────────── Factory location (3 chars)
```

**Key Source Functions:**
```c
// Serial number generation
static void generate_serial(SERIALINFO *info);

// Serial number decoding
static int32_t get_serial_info(const char *serial, SERIALINFO *info);

// MLB (Main Logic Board) generation
static void generate_mlb(SERIALINFO *info, char *dst);

// Model code lookup
static int get_model_code(const char *model, uint32_t *model_code);
```

**Direct Source Links:**
- Main source: https://github.com/acidanthera/OpenCorePkg/blob/master/Utilities/macserial/macserial.c
- Model database: https://github.com/acidanthera/OpenCorePkg/blob/master/Utilities/macserial/modelinfo.h
- Makefile: https://github.com/acidanthera/OpenCorePkg/blob/master/Utilities/macserial/Makefile

---

### 4. irecovery (Open Source)

**Purpose:** Communication tool for iOS/T2 devices in Recovery/DFU mode.

**Origin:** libimobiledevice project (LGPL 2.1 License)

**Repository:** https://github.com/libimobiledevice/libirecovery

**Version in Bundle:** 1.0.1

**Build from Source:**
```bash
git clone https://github.com/libimobiledevice/libirecovery.git
cd libirecovery
./autogen.sh
make
sudo make install
```

**Command Line Options:**
```
Usage: irecovery [OPTIONS]

Interact with an iOS device in DFU or recovery mode.

OPTIONS:
  -i, --ecid ECID    connect to specific device by its ECID
  -c, --command CMD  run CMD on device
  -m, --mode         print current device mode
  -f, --file FILE    send file to device
  -k, --payload FILE send limera1n usb exploit payload from FILE
  -r, --reset        reset client
  -n, --normal       reboot device into normal mode (exit recovery loop)
  -e, --script FILE  executes recovery script from FILE
  -s, --shell        start an interactive shell
  -q, --query        query device info
  -a, --devices      list information for all known devices
  -v, --verbose      enable verbose output
  -h, --help         prints usage information
  -V, --version      prints version information
```

**Example Usage:**
```bash
# Start interactive shell with device in recovery mode
./irecovery -s

# Send file to device
./irecovery -f firmware.img4

# Execute command on device
./irecovery -c "printenv"

# Query device information
./irecovery -q
```

**Key Functions:**
- Communicate with device in DFU/Recovery mode
- Send commands to iBoot/iBSS
- Upload files to device
- Query device ECID, CPID, model info

**Direct Source Links:**
- Repository: https://github.com/libimobiledevice/libirecovery
- Main tool: https://github.com/libimobiledevice/libirecovery/blob/master/tools/irecovery.c

---

### 5. gaster (Open Source)

**Purpose:** Checkm8 DFU exploit tool for T2 chips.

**Origin:** Based on checkm8 exploit by axi0mX (MIT License)

**Repository:** https://github.com/0x7ff/gaster

**Build from Source:**
```bash
git clone https://github.com/0x7ff/gaster.git
cd gaster
make
```

**Command Line Usage:**
```bash
# Exploit device in DFU mode (checkm8)
./gaster pwn

# Reset device
./gaster reset

# Decrypt keybags
./gaster decrypt_kbag <kbag>
```

**Supported Devices:**
- All A5-A11 devices (iPhone 4S through iPhone X)
- T2 Security Chip (used in Intel Macs 2018-2020)

**How It Works:**
1. Device must be in DFU mode
2. Exploits use-after-free vulnerability in bootrom USB code
3. Achieves code execution before secure boot chain
4. Allows loading unsigned code

**Key Source Files:**
| File | Description |
|------|-------------|
| `gaster.c` | Main exploit implementation |
| `checkm8.c` | Checkm8 exploit payload |
| `usb.c` | USB communication layer |

**Purpose in T2BoysSN-Changer Workflow:**
1. Device is put into DFU mode
2. `gaster pwn` exploits the bootrom vulnerability
3. Device bootrom is now in pwned state
4. Custom diagnostic images can be loaded via irecovery

**Direct Source Links:**
- Repository: https://github.com/0x7ff/gaster
- Original checkm8: https://github.com/axi0mX/ipwndfu

**Related Projects:**
- ipwndfu (original Python implementation): https://github.com/axi0mX/ipwndfu
- checkra1n (jailbreak using checkm8): https://checkra.in/

---

### 6. boot.img4

**Purpose:** Encrypted boot image for T2 diagnostic mode.

**Format:** IMG4 container format (Apple's signed image format)

**Encryption:**
- Algorithm: AES-256-ECB
- Key Derivation: PBKDF2-HMAC-SHA1
- Salt: `ECEJWQXAIFQGCI` (hardcoded)
- Iterations: 10,000
- Passphrase: `T2BoysDecryptionKey` (from code analysis)

**Decryption Code Path:**
```objc
- (void)decryptBootImageAtPath:(NSString *)path {
    NSData *encryptedData = [NSData dataWithContentsOfFile:path];
    NSData *salt = [@"ECEJWQXAIFQGCI" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *key = [EncryptionUtility generateKeyFromPassphrase:@"T2BoysDecryptionKey"
                                                          salt:salt];
    NSData *decryptedData = [EncryptionUtility decryptData:encryptedData
                                             decryptionKey:key];
    // ... save decrypted data
}
```

---

### 7. bootchains/[MODEL]/diags

**Purpose:** Model-specific encrypted diagnostic boot files.

**Supported T2 Mac Models:**

| Model ID | Device | Year |
|----------|--------|------|
| A1862 | iMac Pro | 2017 |
| A1932 | MacBook Air | 2018-2019 |
| A1989 | MacBook Pro 13" | 2018-2019 |
| A1990 | MacBook Pro 15" | 2018-2019 |
| A1991 | MacBook Pro 15" (variant) | 2018-2019 |
| A1993 | Mac Mini | 2018 |
| A2115 | iMac 27" | 2019-2020 |
| A2115v2 | iMac 27" (variant) | 2019-2020 |
| A2141 | MacBook Pro 16" | 2019 |
| A2159 | MacBook Pro 13" | 2019 |
| A2179 | MacBook Air | 2020 |
| A2251 | MacBook Pro 13" | 2020 |
| A2289 | MacBook Pro 13" | 2020 |

**Selection Logic:**
```objc
- (NSString *)diagsPathForModel:(NSString *)modelIdentifier {
    NSString *bootchainsPath = [[NSBundle mainBundle]
        pathForResource:@"bootchains"
                 ofType:nil
            inDirectory:@"RES/LIBRARY"];

    return [NSString stringWithFormat:@"%@/%@/diags",
            bootchainsPath, modelIdentifier];
}
```

**Encryption:** Same as boot.img4 (AES-256 with PBKDF2 key)

---

## Workflow Integration

### Complete Operation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    1. Device Detection                       │
│  - Detect connected Mac in DFU mode via IOKit                │
│  - Read ProductType to determine model (A1989, A2141, etc.) │
└─────────────────────────────────┬───────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    2. Exploit Execution                      │
│  - Run: gaster pwn                                           │
│  - Device bootrom is now exploited                           │
└─────────────────────────────────┬───────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│                 3. Load Diagnostic Image                     │
│  - Decrypt model-specific diags file                         │
│  - Send via irecovery to device                             │
│  - Device boots into diagnostic mode                         │
└─────────────────────────────────┬───────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│                 4. Serial Port Communication                 │
│  - Connect via serial port at 115200 baud                    │
│  - Send: serialnumber\r\n (read current)                     │
│  - Send: setsn <NEW_SN>\r\n (write new)                     │
└─────────────────────────────────┬───────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    5. Serial Generation                      │
│  - Use macserial to generate valid serial                    │
│  - Or use internal generateSerialNumber method              │
└─────────────────────────────────────────────────────────────┘
```

---

## File Format Analysis

### boot.img4 / diags Files

**Header Analysis:**
```
Offset 0x00: Encrypted data (no recognizable header)
First bytes: Random-looking data due to AES encryption
```

**After Decryption:** Expected to be IMG4 format:
```
Offset 0x00: 30 XX XX XX (ASN.1 SEQUENCE)
Contains:
  - IM4P payload
  - Manifest (optional)
  - Signature data
```

---

## Security Notes

1. **Hardcoded Encryption Keys:** The passphrase and salt are embedded in the binary, making decryption possible for anyone with access to the code.

2. **x86_64 Binaries:** The helper tools (macserial, irecovery, gaster) are x86_64 only and require Rosetta 2 on Apple Silicon Macs.

3. **Unsigned Binaries:** The helper tools are not code-signed and will require security exceptions to run.

---

## Build Integration

The `build.sh --bundle` command now copies all Resources:

```bash
./build.sh --bundle
```

Creates:
```
T2BoysSN-Changer.app/
├── Contents/
│   ├── MacOS/
│   │   └── T2BoysSN-Changer
│   ├── Frameworks/
│   │   └── ORSSerial.framework/
│   ├── Resources/
│   │   ├── AppIcon.icns
│   │   ├── Assets.car
│   │   ├── macserial
│   │   ├── Main.storyboardc/
│   │   └── RES/
│   │       ├── irecovery
│   │       ├── ipwnders/gaster
│   │       └── LIBRARY/
│   │           ├── boot.img4
│   │           └── bootchains/...
│   └── Info.plist
```

---

## References

- OpenCore macserial: https://github.com/acidanthera/OpenCorePkg
- libirecovery: https://github.com/libimobiledevice/libirecovery
- checkm8 exploit: https://github.com/axi0mX/ipwndfu
- Apple IMG4 format: https://www.theiphonewiki.com/wiki/IMG4_File_Format
