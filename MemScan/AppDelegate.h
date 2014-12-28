//
//  AppDelegate.h
//  MemScan
//
//  Created by Joe Savage on 25/12/2014.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ProcessSelectionWindowController;
@class ScannerWindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    ProcessSelectionWindowController *_processSelectionWindowController;
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification;
- (void) applicationWillTerminate:(NSNotification *)notification;
- (BOOL) applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)hasVisibleWindows;

@end

