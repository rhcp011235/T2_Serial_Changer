//
//  ViewController.m
//  TheT2BoysSN-Changer
//
//  Reconstructed from IDA dump
//

#import "ViewController.h"
#import "Encryption.h"
#import "EncryptionUtility.h"
#import <IOKit/IOKitLib.h>

// Global state variables (from dump lines 3531598-3531618)
static NSString *MODE_INFO = @"Disconnected";
static NSString *ECID_INFO = @"";
static NSString *CPID_INFO = @"";
static NSString *ProductType = @"";
static NSString *SN_INFO = @"";
static NSString *Support_INFO = @"";
static NSString *NAME_INFO = @"";

// File name constants (from FileNameTmp array)
static NSString * const kFileTmp = @"file.tmp";
static NSString * const kInProgress = @"in_progress";
static NSString * const kAlpine = @"alpine";

// Service identifier
static NSString * const kServiceActivationLock = @"Activationlock";

// Flag for DFU detection
static BOOL is_detect_dfu_handle_active = YES;

// Hardware info array index constants
typedef NS_ENUM(NSUInteger, HWInfoIndex) {
    HWInfoIndexECID = 0,
    HWInfoIndexCPID,
    HWInfoIndexProductType,
    HWInfoIndexModel,
    HWInfoIndexBoardID,
    HWInfoIndexChipID,
    HWInfoIndexCount
};

@interface ViewController ()
@property (nonatomic, strong) NSArray<ORSSerialPort *> *availablePorts;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@end

@implementation ViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.receivedData = [NSMutableData data];
    self.serialQueue = dispatch_queue_create("com.t2boys.serial", DISPATCH_QUEUE_SERIAL);

    // Setup serial port manager notification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(serialPortsWereConnected:)
                                                 name:ORSSerialPortsWereConnectedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(serialPortsWereDisconnected:)
                                                 name:ORSSerialPortsWereDisconnectedNotification
                                               object:nil];

    [self refreshSerialPort:nil];
    [self versionCheck];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.serialPort.isOpen) {
        [self.serialPort close];
    }
}

#pragma mark - Serial Port Management (from dump lines 42577, 63128)

- (IBAction)refreshSerialPort:(id)sender {
    // Original function: -[ViewController refreshSerialPort:]
    // Implementation around line 7893295

    self.availablePorts = [[ORSSerialPortManager sharedSerialPortManager] availablePorts];

    [self.serialPortPopup removeAllItems];

    for (ORSSerialPort *port in self.availablePorts) {
        [self.serialPortPopup addItemWithTitle:port.name];
    }

    if (self.availablePorts.count > 0) {
        [self.serialPortPopup selectItemAtIndex:0];
    }
}

- (IBAction)connectToSerialPort:(id)sender {
    // Connect/disconnect from selected serial port

    if (self.isSerialPortConnected) {
        [self.serialPort close];
        self.serialPort = nil;
        self.isSerialPortConnected = NO;
        [self.serialConnectBTN setTitle:@"Connect"];
        MODE_INFO = @"Disconnected";
    } else {
        NSInteger selectedIndex = [self.serialPortPopup indexOfSelectedItem];
        if (selectedIndex >= 0 && selectedIndex < self.availablePorts.count) {
            self.serialPort = self.availablePorts[selectedIndex];
            self.serialPort.delegate = self;
            self.serialPort.baudRate = @115200;
            [self.serialPort open];
        }
    }
}

- (void)autoConnectToSerialPort {
    // Original function at line 63128 in dump
    // Auto-connect to first available port

    if (self.availablePorts.count > 0) {
        self.serialPort = self.availablePorts.firstObject;
        self.serialPort.delegate = self;
        self.serialPort.baudRate = @115200;
        [self.serialPort open];
    }
}

#pragma mark - ORSSerialPortDelegate

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort {
    self.isSerialPortConnected = YES;
    [self.serialConnectBTN setTitle:@"Disconnect"];
    MODE_INFO = @"Connected";
    NSLog(@"Serial port opened: %@", serialPort.name);

    // Read serial number after connecting
    [self readSerialNumber];
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort {
    self.isSerialPortConnected = NO;
    [self.serialConnectBTN setTitle:@"Connect"];
    MODE_INFO = @"Disconnected";
    NSLog(@"Serial port closed: %@", serialPort.name);
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data {
    // Process received data
    [self.receivedData appendData:data];

    NSString *receivedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (receivedString) {
        NSLog(@"Received: %@", receivedString);
        [self processReceivedData:receivedString];
    }
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error {
    NSLog(@"Serial port error: %@", error.localizedDescription);
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort {
    self.serialPort = nil;
    self.isSerialPortConnected = NO;
    MODE_INFO = @"Disconnected";
    [self refreshSerialPort:nil];
}

#pragma mark - Serial Port Notifications

- (void)serialPortsWereConnected:(NSNotification *)notification {
    [self refreshSerialPort:nil];
}

- (void)serialPortsWereDisconnected:(NSNotification *)notification {
    [self refreshSerialPort:nil];
}

#pragma mark - Serial Number Operations (from dump lines 45114, 52931, 64445)

- (void)getSerialNumber {
    // Original function at line 45114 in dump
    // Implementation around line 7526547

    io_service_t platformExpert = IOServiceGetMatchingService(
        kIOMasterPortDefault,
        IOServiceMatching("IOPlatformExpertDevice")
    );

    if (platformExpert) {
        CFTypeRef serialNumberAsCFString = IORegistryEntryCreateCFProperty(
            platformExpert,
            CFSTR("IOPlatformSerialNumber"),
            kCFAllocatorDefault,
            0
        );

        if (serialNumberAsCFString) {
            SN_INFO = (__bridge_transfer NSString *)serialNumberAsCFString;
            self.oldSerialNumber = SN_INFO;
            NSLog(@"Current Serial Number: %@", SN_INFO);
        }

        IOObjectRelease(platformExpert);
    }
}

- (void)readSerialNumber {
    // Original function at line 64445 in dump
    // Send command to read serial number from device
    // Implementation around line 7893295

    if (!self.isSerialPortConnected) {
        NSLog(@"Serial port not connected");
        return;
    }

    // Command to read serial number (device-specific command)
    NSString *readCommand = @"serialnumber\r\n";
    NSData *commandData = [readCommand dataUsingEncoding:NSUTF8StringEncoding];

    [self sendData:commandData];
}

- (void)writeSN {
    // Original function at line 51288 in dump
    // Write serial number to device
    // Implementation around line 7642162

    if (!self.isSerialPortConnected) {
        NSLog(@"Serial port not connected");
        return;
    }

    NSString *newSerialNumber = [self formattedSerialNumberFromTextField:self.SN_Field];

    if (!newSerialNumber || newSerialNumber.length == 0) {
        NSLog(@"Invalid serial number");
        return;
    }

    // Sanitize the serial number
    NSString *sanitizedSN = [self sanitizeSerialNumber:newSerialNumber];

    // Log the change
    [self logSerialNumberChangeForAuthorizedDeviceWithOldSerialNumber:self.oldSerialNumber
                                                      newSerialNumber:sanitizedSN];

    // Send write command
    NSString *writeCommand = [NSString stringWithFormat:@"setsn %@\r\n", sanitizedSN];
    NSData *commandData = [writeCommand dataUsingEncoding:NSUTF8StringEncoding];

    [self sendData:commandData];
}

- (void)generateSerialNumber {
    // Original function at line 52931 in dump
    // Generate a random valid serial number
    // Implementation around line 7674907

    // Apple serial number format: XXYYWWZZPPP (12 characters for newer models)
    // XX = Manufacturing location
    // YY = Year of manufacture
    // WW = Week of manufacture
    // ZZ = Unique identifier
    // PPP = Model identifier

    NSString *locations = @"CDFGHJKLMNPQRSTVWXYZ";
    NSString *chars = @"0123456789ABCDEFGHJKLMNPQRSTUVWXYZ";

    NSMutableString *serialNumber = [NSMutableString string];

    // Location code (2 chars)
    for (int i = 0; i < 2; i++) {
        uint32_t index = arc4random_uniform((uint32_t)locations.length);
        [serialNumber appendFormat:@"%C", [locations characterAtIndex:index]];
    }

    // Year + Week (4 chars)
    for (int i = 0; i < 4; i++) {
        uint32_t index = arc4random_uniform((uint32_t)chars.length);
        [serialNumber appendFormat:@"%C", [chars characterAtIndex:index]];
    }

    // Unique ID (3 chars)
    for (int i = 0; i < 3; i++) {
        uint32_t index = arc4random_uniform((uint32_t)chars.length);
        [serialNumber appendFormat:@"%C", [chars characterAtIndex:index]];
    }

    // Model identifier (3 chars)
    for (int i = 0; i < 3; i++) {
        uint32_t index = arc4random_uniform((uint32_t)chars.length);
        [serialNumber appendFormat:@"%C", [chars characterAtIndex:index]];
    }

    [self.SN_Field setStringValue:serialNumber];
}

- (NSString *)sanitizeSerialNumber:(NSString *)serialNumber {
    // Original function at line 53644 in dump
    // Implementation around line 7687871

    if (!serialNumber) {
        return nil;
    }

    // Remove whitespace and newlines
    NSString *sanitized = [serialNumber stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // Remove invalid characters (keep only alphanumeric)
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger i = 0; i < sanitized.length; i++) {
        unichar c = [sanitized characterAtIndex:i];
        if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:c]) {
            [result appendFormat:@"%C", c];
        }
    }

    // Convert to uppercase
    return [result uppercaseString];
}

- (NSDictionary *)parseSerialNumber:(NSString *)serialNumber {
    // Original function at line 54018 in dump
    // Parse serial number into components
    // Implementation around line 7696115

    if (!serialNumber || serialNumber.length < 11) {
        return nil;
    }

    NSMutableDictionary *parsed = [NSMutableDictionary dictionary];

    // For 12-character serial (newer format)
    if (serialNumber.length >= 12) {
        parsed[@"location"] = [serialNumber substringWithRange:NSMakeRange(0, 2)];
        parsed[@"year"] = [serialNumber substringWithRange:NSMakeRange(2, 1)];
        parsed[@"week"] = [serialNumber substringWithRange:NSMakeRange(3, 2)];
        parsed[@"uniqueId"] = [serialNumber substringWithRange:NSMakeRange(5, 3)];
        parsed[@"modelCode"] = [serialNumber substringWithRange:NSMakeRange(8, 4)];
    }
    // For 11-character serial (older format)
    else if (serialNumber.length == 11) {
        parsed[@"location"] = [serialNumber substringWithRange:NSMakeRange(0, 2)];
        parsed[@"year"] = [serialNumber substringWithRange:NSMakeRange(2, 1)];
        parsed[@"week"] = [serialNumber substringWithRange:NSMakeRange(3, 2)];
        parsed[@"uniqueId"] = [serialNumber substringWithRange:NSMakeRange(5, 3)];
        parsed[@"modelCode"] = [serialNumber substringWithRange:NSMakeRange(8, 3)];
    }

    return [parsed copy];
}

- (NSString *)formattedSerialNumberFromTextField:(NSTextField *)textField {
    // Original function at line 64044 in dump
    // Implementation around line 7886102

    NSString *value = [textField stringValue];
    return [self sanitizeSerialNumber:value];
}

#pragma mark - Data Operations (from dump line 64658)

- (void)sendData:(NSData *)data {
    // Original function at line 64658 in dump
    // Implementation around line 7896533

    if (!self.serialPort || !self.serialPort.isOpen) {
        NSLog(@"Cannot send data: serial port not open");
        return;
    }

    dispatch_async(self.serialQueue, ^{
        [self.serialPort sendData:data];
    });
}

- (void)processReceivedData:(NSString *)data {
    // Process received serial data and update UI

    if ([data containsString:@"Serial:"]) {
        // Extract serial number from response
        NSArray *components = [data componentsSeparatedByString:@":"];
        if (components.count > 1) {
            NSString *serialNumber = [self sanitizeSerialNumber:components[1]];
            self.oldSerialNumber = serialNumber;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.SN_Field setStringValue:serialNumber];
            });
        }
    }
}

#pragma mark - Boot Image Decryption (from dump lines 56043, 65508)

- (void)decryptBootImageAtPath:(NSString *)path {
    // Original function at line 56043 in dump
    // Implementation around line 7733182
    // NOTE: Encryption details unverified - files may be sent as-is to device

    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"[ViewController] Boot image not found at path: %@", path);
        return;
    }

    // IMPORTANT: These files appear to be Apple-encrypted IMG4 images
    // They may be sent directly to the device without app-level decryption
    // The T2 chip likely handles decryption using hardware keys

    NSLog(@"[ViewController] Preparing boot image at: %@", path);

    NSData *imageData = [NSData dataWithContentsOfFile:path];
    if (!imageData) {
        NSLog(@"[ViewController] Failed to read image data");
        return;
    }

    // Copy to temp directory for irecovery to access
    NSString *tempPath = [self decryptedDiagsPath];
    NSError *error = nil;

    // Create directory if needed
    [[NSFileManager defaultManager] createDirectoryAtPath:[tempPath stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];

    // Write data (may still be encrypted - device handles decryption)
    [imageData writeToFile:tempPath atomically:YES];
    NSLog(@"[ViewController] ✓ Boot image prepared at: %@", tempPath);
    NSLog(@"[ViewController] Size: %lu bytes", (unsigned long)imageData.length);
    NSLog(@"[ViewController] Note: File sent as-is to device (Apple-encrypted IMG4)");
}

- (NSString *)decryptedDiagsPath {
    // Original function at line 65508 in dump
    // Implementation around line 7910440
    // Returns path where decrypted diagnostic images are stored

    NSString *tempDir = NSTemporaryDirectory();
    return [tempDir stringByAppendingPathComponent:@"decrypted_diags.img4"];
}

- (NSString *)bootImagePath {
    // Get path to encrypted boot.img4 in bundle
    NSString *libraryPath = [[NSBundle mainBundle] pathForResource:@"boot"
                                                            ofType:@"img4"
                                                       inDirectory:@"RES/LIBRARY"];
    return libraryPath;
}

- (NSString *)diagsPathForModel:(NSString *)modelIdentifier {
    // Get path to encrypted diags file for specific model
    // Model identifiers: A1862, A1932, A1989, A1990, A1991, A1993, A2115, A2115v2, A2141, A2159, A2179, A2251, A2289

    if (!modelIdentifier || modelIdentifier.length == 0) {
        NSLog(@"[ViewController] No model identifier provided");
        return nil;
    }

    NSString *bootchainsPath = [[NSBundle mainBundle] pathForResource:@"bootchains"
                                                               ofType:nil
                                                          inDirectory:@"RES/LIBRARY"];

    if (!bootchainsPath) {
        NSLog(@"[ViewController] Bootchains directory not found in bundle");
        return nil;
    }

    NSString *diagsPath = [NSString stringWithFormat:@"%@/%@/diags", bootchainsPath, modelIdentifier];

    if (![[NSFileManager defaultManager] fileExistsAtPath:diagsPath]) {
        NSLog(@"[ViewController] Diags file not found for model: %@", modelIdentifier);
        return nil;
    }

    NSLog(@"[ViewController] Found diags for model %@: %@", modelIdentifier, diagsPath);
    return diagsPath;
}

- (void)prepareAndLoadDiagsForModel:(NSString *)modelIdentifier {
    // Complete workflow: locate and prepare diags file for device
    // This is called after device model is detected
    // Note: Files are Apple-encrypted IMG4, sent as-is to device

    NSLog(@"[ViewController] Preparing diags for model: %@", modelIdentifier);

    // Get path to diags file
    NSString *diagsPath = [self diagsPathForModel:modelIdentifier];
    if (!diagsPath) {
        NSLog(@"[ViewController] Cannot find diags for model: %@", modelIdentifier);
        return;
    }

    // Copy/prepare the diags file (sent as-is, Apple-encrypted)
    [self decryptBootImageAtPath:diagsPath];

    NSLog(@"[ViewController] ✓ Diags ready for upload to device");
}

#pragma mark - DFU Mode & Device Communication

- (void)executeGasterPwn {
    // Execute gaster exploit to pwn T2 bootrom
    // Implements checkm8 exploit via gaster binary
    // Found at: Resources/RES/ipwnders/gaster

    NSLog(@"[ViewController] === Executing Gaster PWN (checkm8 exploit) ===");

    NSString *gasterPath = [[NSBundle mainBundle] pathForResource:@"gaster"
                                                           ofType:nil
                                                      inDirectory:@"RES/ipwnders"];

    if (!gasterPath || ![[NSFileManager defaultManager] fileExistsAtPath:gasterPath]) {
        NSLog(@"[ViewController] ✗ Gaster binary not found in bundle");
        [self.statusLabel setStringValue:@"Error: gaster not found"];
        return;
    }

    // Make executable
    NSTask *chmodTask = [[NSTask alloc] init];
    [chmodTask setLaunchPath:@"/bin/chmod"];
    [chmodTask setArguments:@[@"+x", gasterPath]];
    [chmodTask launch];
    [chmodTask waitUntilExit];

    // Execute: gaster pwn
    NSTask *gasterTask = [[NSTask alloc] init];
    [gasterTask setLaunchPath:gasterPath];
    [gasterTask setArguments:@[@"pwn"]];

    NSPipe *outputPipe = [NSPipe pipe];
    [gasterTask setStandardOutput:outputPipe];
    [gasterTask setStandardError:outputPipe];

    NSLog(@"[ViewController] Executing: %@ pwn", gasterPath);
    [self.statusLabel setStringValue:@"Exploiting T2 bootrom..."];

    [gasterTask launch];
    [gasterTask waitUntilExit];

    int exitCode = [gasterTask terminationStatus];

    // Read output
    NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    if (exitCode == 0) {
        NSLog(@"[ViewController] ✓ Gaster PWN successful!");
        NSLog(@"[ViewController] Output: %@", output);
        [self.statusLabel setStringValue:@"T2 bootrom exploited ✓"];
    } else {
        NSLog(@"[ViewController] ✗ Gaster PWN failed with exit code: %d", exitCode);
        NSLog(@"[ViewController] Output: %@", output);
        [self.statusLabel setStringValue:@"Exploit failed - check device is in DFU mode"];
    }
}

- (void)sendDiagsToDevice:(NSString *)diagsPath {
    // Send decrypted diagnostic image to T2 device via irecovery
    // Uses irecovery binary from Resources/RES/irecovery

    if (!diagsPath || ![[NSFileManager defaultManager] fileExistsAtPath:diagsPath]) {
        NSLog(@"[ViewController] ✗ Diags file not found: %@", diagsPath);
        return;
    }

    NSLog(@"[ViewController] === Sending diags to device via irecovery ===");

    NSString *irecoveryPath = [[NSBundle mainBundle] pathForResource:@"irecovery"
                                                              ofType:nil
                                                         inDirectory:@"RES"];

    if (!irecoveryPath || ![[NSFileManager defaultManager] fileExistsAtPath:irecoveryPath]) {
        NSLog(@"[ViewController] ✗ irecovery binary not found in bundle");
        [self.statusLabel setStringValue:@"Error: irecovery not found"];
        return;
    }

    // Make executable
    NSTask *chmodTask = [[NSTask alloc] init];
    [chmodTask setLaunchPath:@"/bin/chmod"];
    [chmodTask setArguments:@[@"+x", irecoveryPath]];
    [chmodTask launch];
    [chmodTask waitUntilExit];

    // Execute: irecovery -f <diags_path>
    NSTask *irecoveryTask = [[NSTask alloc] init];
    [irecoveryTask setLaunchPath:irecoveryPath];
    [irecoveryTask setArguments:@[@"-f", diagsPath]];

    NSPipe *outputPipe = [NSPipe pipe];
    [irecoveryTask setStandardOutput:outputPipe];
    [irecoveryTask setStandardError:outputPipe];

    NSLog(@"[ViewController] Executing: %@ -f %@", irecoveryPath, diagsPath);
    [self.statusLabel setStringValue:@"Uploading diagnostic image..."];
    [self.progressIndicator startAnimation:self];

    [irecoveryTask launch];
    [irecoveryTask waitUntilExit];

    [self.progressIndicator stopAnimation:self];

    int exitCode = [irecoveryTask terminationStatus];

    // Read output
    NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    if (exitCode == 0) {
        NSLog(@"[ViewController] ✓ Diags uploaded successfully!");
        NSLog(@"[ViewController] Output: %@", output);
        [self.statusLabel setStringValue:@"Diagnostic mode loaded ✓"];
    } else {
        NSLog(@"[ViewController] ✗ irecovery failed with exit code: %d", exitCode);
        NSLog(@"[ViewController] Output: %@", output);
        [self.statusLabel setStringValue:@"Upload failed"];
    }
}

- (NSString *)detectDeviceModel {
    // Detect connected T2 Mac model via irecovery -q
    // Returns model identifier like "A2141", "A1989", etc.

    NSLog(@"[ViewController] === Detecting device model ===");

    NSString *irecoveryPath = [[NSBundle mainBundle] pathForResource:@"irecovery"
                                                              ofType:nil
                                                         inDirectory:@"RES"];

    if (!irecoveryPath) {
        NSLog(@"[ViewController] ✗ irecovery not found");
        return nil;
    }

    // Make executable
    NSTask *chmodTask = [[NSTask alloc] init];
    [chmodTask setLaunchPath:@"/bin/chmod"];
    [chmodTask setArguments:@[@"+x", irecoveryPath]];
    [chmodTask launch];
    [chmodTask waitUntilExit];

    // Execute: irecovery -q
    NSTask *irecoveryTask = [[NSTask alloc] init];
    [irecoveryTask setLaunchPath:irecoveryPath];
    [irecoveryTask setArguments:@[@"-q"]];

    NSPipe *outputPipe = [NSPipe pipe];
    [irecoveryTask setStandardOutput:outputPipe];

    [irecoveryTask launch];
    [irecoveryTask waitUntilExit];

    // Read output
    NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    // Parse output for model identifier
    // Look for "PRODUCT:" line which contains model like "iBridge2,15" -> maps to A2141
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    NSString *modelIdentifier = nil;

    for (NSString *line in lines) {
        if ([line containsString:@"MODEL:"]) {
            // Extract model number
            NSArray *parts = [line componentsSeparatedByString:@":"];
            if (parts.count > 1) {
                modelIdentifier = [[parts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
                break;
            }
        }
    }

    if (modelIdentifier) {
        NSLog(@"[ViewController] ✓ Detected model: %@", modelIdentifier);
    } else {
        NSLog(@"[ViewController] ✗ Could not detect model from irecovery output");
        NSLog(@"[ViewController] Output: %@", output);
    }

    return modelIdentifier;
}

- (void)completeT2BootSequence {
    // Complete workflow: DFU -> Exploit -> Detect -> Decrypt -> Load Diags
    // This orchestrates the entire T2 boot sequence for serial number modification

    NSLog(@"\n");
    NSLog(@"[ViewController] ========================================");
    NSLog(@"[ViewController] STARTING T2 BOOT SEQUENCE");
    NSLog(@"[ViewController] ========================================");

    // Step 1: Execute gaster pwn (checkm8 exploit)
    [self.statusLabel setStringValue:@"Step 1/4: Exploiting bootrom..."];
    [self executeGasterPwn];

    // Small delay to let device stabilize
    [NSThread sleepForTimeInterval:2.0];

    // Step 2: Detect device model
    [self.statusLabel setStringValue:@"Step 2/4: Detecting device model..."];
    NSString *modelIdentifier = [self detectDeviceModel];

    if (!modelIdentifier) {
        NSLog(@"[ViewController] ✗ Cannot proceed without model detection");
        [self.statusLabel setStringValue:@"Error: Model detection failed"];
        return;
    }

    // Step 3: Prepare appropriate diags file
    [self.statusLabel setStringValue:[NSString stringWithFormat:@"Step 3/4: Preparing diags for %@...", modelIdentifier]];
    [self prepareAndLoadDiagsForModel:modelIdentifier];

    // Step 4: Send diags to device
    [self.statusLabel setStringValue:@"Step 4/4: Loading diagnostic mode..."];
    NSString *decryptedDiagsPath = [self decryptedDiagsPath];
    [self sendDiagsToDevice:decryptedDiagsPath];

    NSLog(@"[ViewController] ========================================");
    NSLog(@"[ViewController] T2 BOOT SEQUENCE COMPLETE");
    NSLog(@"[ViewController] Device should now be in diagnostic mode");
    NSLog(@"[ViewController] Serial port should be available for SN modification");
    NSLog(@"[ViewController] ========================================");
    NSLog(@"\n");

    // Auto-connect to serial port
    [self performSelector:@selector(autoConnectToSerialPort) withObject:nil afterDelay:3.0];
}

#pragma mark - Logging (from dump line 52032)

- (void)logSerialNumberChangeForAuthorizedDeviceWithOldSerialNumber:(NSString *)oldSN
                                                    newSerialNumber:(NSString *)newSN {
    // Original function at line 52032 in dump
    // Implementation around line 7656156

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];

    NSString *logEntry = [NSString stringWithFormat:@"[%@] Serial Number Changed: %@ -> %@",
                          timestamp, oldSN ?: @"Unknown", newSN];

    NSLog(@"%@", logEntry);

    // Append to log file
    NSString *logPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sn_change.log"];

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[[logEntry stringByAppendingString:@"\n"]
                               dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    } else {
        [[logEntry stringByAppendingString:@"\n"]
         writeToFile:logPath
          atomically:YES
            encoding:NSUTF8StringEncoding
               error:nil];
    }
}

#pragma mark - Network Operations (from dump lines 46835, 47038)

- (void)versionCheck {
    // Original function at line 46835 in dump
    // Check for application updates

    NSURL *url = [NSURL URLWithString:@"https://pepajos.com/T2SNCHANGERX/versi0n.php"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data,
                                                                NSURLResponse *response,
                                                                NSError *error) {
        if (error) {
            NSLog(@"Version check failed: %@", error.localizedDescription);
            return;
        }

        // Parse version response
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:nil];
        if (json[@"version"]) {
            NSLog(@"Latest version: %@", json[@"version"]);
        }
    }];

    [task resume];
}

- (void)sendLogs {
    // Original function at line 47038 in dump
    // Send diagnostic logs to server

    NSString *logPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sn_change.log"];
    NSData *logData = [NSData dataWithContentsOfFile:logPath];

    if (!logData) {
        return;
    }

    NSURL *url = [NSURL URLWithString:@"https://api.t2boys.com/logs"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:logData];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData *data,
                                                                NSURLResponse *response,
                                                                NSError *error) {
        if (error) {
            NSLog(@"Failed to send logs: %@", error.localizedDescription);
        } else {
            NSLog(@"Logs sent successfully");
        }
    }];

    [task resume];
}

@end
