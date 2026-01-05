//
//  AppDelegate.m
//  TheT2BoysSN-Changer
//
//  Reconstructed from IDA dump
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "EncryptionUtility.h"

@interface AppDelegate ()
@property (nonatomic, strong) ViewController *mainViewController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Original function at line 100154 in dump
    // Implementation around line 7029390 (sub_1007B5570)

    NSLog(@"T2BoysSN-Changer launching...");

    // Initialize encryption system
    [EncryptionUtility initialize];

    // Setup main window
    [self setupMainWindow];

    NSLog(@"Application ready");
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // Cleanup before termination
    NSLog(@"Application terminating...");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

#pragma mark - Window Setup

- (void)setupMainWindow {
    // Create main window
    NSRect frame = NSMakeRect(0, 0, 600, 400);
    NSWindowStyleMask styleMask = NSWindowStyleMaskTitled |
                                   NSWindowStyleMaskClosable |
                                   NSWindowStyleMaskMiniaturizable |
                                   NSWindowStyleMaskResizable;

    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:styleMask
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];

    [self.window setTitle:@"T2Boys SN Changer"];
    [self.window center];

    // Create and set view controller
    self.mainViewController = [[ViewController alloc] init];
    [self.window setContentViewController:self.mainViewController];

    [self.window makeKeyAndOrderFront:nil];
}

@end
