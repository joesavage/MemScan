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
    [_processSelectionWindowController initiateWindowAction];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [_processSelectionWindowController release];
    _processSelectionWindowController = nil;
}

@end
