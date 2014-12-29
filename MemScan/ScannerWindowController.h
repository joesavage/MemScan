//
//  ScannerWindowController.h
//  MemScan
//
//  Created by Joe Savage on 28/12/2014.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ScannerWindowController : NSWindowController
{
             NSDictionary *_process;
    IBOutlet NSTextField  *_processLabel;
}

- (id) init;
- (void) dealloc;

- (void) setProcess:(NSDictionary *)process;
- (void) initiateWindowAction;
- (void) windowDidLoad;
- (void) windowWillClose:(NSNotification *)notification;

@end
