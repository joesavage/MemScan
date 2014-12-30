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
             task_t       _task;
             NSDictionary *_process;
    IBOutlet NSButton     *_scanButton;
    IBOutlet NSTextField  *_processLabel;
}

- (id) init;
- (void) dealloc;

- (void) throwFatalError:(NSString *)message;
- (void) handleKernReturn:(kern_return_t)error forFunction:(NSString *)function;
- (void) setProcess:(NSDictionary *)process;
- (void) initiateWindowAction;
- (void) windowDidLoad;
- (void) windowWillClose:(NSNotification *)notification;

- (IBAction) initiateScan:(id)sender;

@end
