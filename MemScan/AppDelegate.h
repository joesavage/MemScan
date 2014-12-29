//
//  AppDelegate.h
//  MemScan
//
//  Created by Joe Savage on 25/12/2014.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ProcessSelectionWindowController.h"

@class ScannerWindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate, ProcessSelectionDelegate>
{
    ProcessSelectionWindowController *_processSelectionWindowController;
    ScannerWindowController          *_scannerWindowController;
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification;
- (void) applicationWillTerminate:(NSNotification *)notification;
- (BOOL) applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)hasVisibleWindows;

- (void) processSelected:(NSDictionary *)process;

@end

