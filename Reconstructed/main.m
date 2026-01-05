//
//  main.m
//  TheT2BoysSN-Changer
//
//  Reconstructed from IDA dump
//  Original main function at line 99969 in dump
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Create the application
        NSApplication *app = [NSApplication sharedApplication];

        // Create and set the delegate
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];

        // Run the application
        [app run];
    }
    return 0;
}
