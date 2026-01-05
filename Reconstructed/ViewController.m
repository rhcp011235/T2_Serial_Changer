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

    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"Boot image not found at path: %@", path);
        return;
    }

    NSData *encryptedData = [NSData dataWithContentsOfFile:path];
    if (!encryptedData) {
        return;
    }

    // Generate decryption key
    NSData *salt = [@"ECEJWQXAIFQGCI" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *key = [EncryptionUtility generateKeyFromPassphrase:@"T2BoysDecryptionKey" salt:salt];

    // Decrypt the boot image
    NSData *decryptedData = [EncryptionUtility decryptData:encryptedData decryptionKey:key];

    if (decryptedData) {
        // Save decrypted boot image
        NSString *decryptedPath = [path stringByAppendingString:@".decrypted"];
        [decryptedData writeToFile:decryptedPath atomically:YES];
        NSLog(@"Boot image decrypted to: %@", decryptedPath);
    }
}

- (NSString *)decryptedDiagsPath {
    // Original function at line 65508 in dump
    // Implementation around line 7910440

    NSString *tempDir = NSTemporaryDirectory();
    return [tempDir stringByAppendingPathComponent:@"decrypted_diags"];
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
