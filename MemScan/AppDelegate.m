//
//  AppDelegate.m
//  MemScan
//
//  Created by Joe Savage on 25/12/2014.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#import "AppDelegate.h"
#import "ProcessSelectionWindowController.h"
#import "ScannerWindowController.h"

@implementation AppDelegate

- (BOOL) applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)hasVisibleWindows {
    if (!hasVisibleWindows)
        [_processSelectionWindowController initiateWindowAction];
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _processSelectionWindowController = [[ProcessSelectionWindowController alloc] init];
    _scannerWindowController = nil;
    
    [_processSelectionWindowController setDelegate:self];
    [_processSelectionWindowController initiateWindowAction];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [_processSelectionWindowController release];
    _processSelectionWindowController = nil;
    [_scannerWindowController release];
    _scannerWindowController = nil;
}

- (void) processSelected:(NSDictionary *)process {
    if (_scannerWindowController == nil)
        _scannerWindowController = [[ScannerWindowController alloc] init];
    
    [_scannerWindowController setProcess:process];
    [_processSelectionWindowController.window close];
    [_scannerWindowController initiateWindowAction];
}

@end
