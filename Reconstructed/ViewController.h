//
//  ViewController.h
//  TheT2BoysSN-Changer
//
//  Reconstructed from IDA dump
//

#import <Cocoa/Cocoa.h>

// ORSSerialPort - https://github.com/armadsen/ORSSerialPort
// Install via CocoaPods: pod 'ORSSerialPort'
// Or build framework manually (see build.sh)
#if __has_include(<ORSSerial/ORSSerial.h>)
    #import <ORSSerial/ORSSerial.h>
#elif __has_include("ORSSerial/ORSSerial.h")
    #import "ORSSerial/ORSSerial.h"
#else
    // Forward declarations if framework not available
    @class ORSSerialPort;
    @class ORSSerialPortManager;
    @protocol ORSSerialPortDelegate;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface ViewController : NSViewController <ORSSerialPortDelegate>

#pragma mark - UI Outlets (from dump lines 66374-68914)
@property (nonatomic, weak) IBOutlet NSButton *WriteSN_BTN;
@property (nonatomic, weak) IBOutlet NSTextField *SN_Field;
@property (nonatomic, weak) IBOutlet NSTextField *SN_Field_DIAG;
@property (nonatomic, weak) IBOutlet NSButton *serialConnectBTN;
@property (nonatomic, weak) IBOutlet NSButton *WriteNewSerialNumber;
@property (nonatomic, weak) IBOutlet NSPopUpButton *serialPortPopup;
@property (nonatomic, weak) IBOutlet NSTextField *statusLabel;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressIndicator;

#pragma mark - Properties
@property (nonatomic, strong, nullable) ORSSerialPort *serialPort;
@property (nonatomic, strong, nullable) NSString *oldSerialNumber;
@property (nonatomic, assign) BOOL isSerialPortConnected;

#pragma mark - Serial Port Actions
- (IBAction)refreshSerialPort:(id)sender;
- (IBAction)connectToSerialPort:(id)sender;
- (void)autoConnectToSerialPort;

#pragma mark - Serial Number Operations
- (void)getSerialNumber;
- (void)readSerialNumber;
- (void)writeSN;
- (void)generateSerialNumber;
- (NSString *)sanitizeSerialNumber:(NSString *)serialNumber;
- (NSDictionary *)parseSerialNumber:(NSString *)serialNumber;
- (NSString *)formattedSerialNumberFromTextField:(NSTextField *)textField;

#pragma mark - Data Operations
- (void)sendData:(NSData *)data;

#pragma mark - Boot Image Decryption & Resource Loading
- (void)decryptBootImageAtPath:(NSString *)path;
- (NSString *)decryptedDiagsPath;
- (NSString *)bootImagePath;
- (NSString *)diagsPathForModel:(NSString *)modelIdentifier;
- (void)prepareAndLoadDiagsForModel:(NSString *)modelIdentifier;

#pragma mark - DFU Mode & Device Communication
- (void)executeGasterPwn;
- (void)sendDiagsToDevice:(NSString *)diagsPath;
- (NSString *)detectDeviceModel;
- (void)completeT2BootSequence;

#pragma mark - Logging
- (void)logSerialNumberChangeForAuthorizedDeviceWithOldSerialNumber:(NSString *)oldSN
                                                    newSerialNumber:(NSString *)newSN;

#pragma mark - Version & Network
- (void)versionCheck;
- (void)sendLogs;

@end

NS_ASSUME_NONNULL_END
