//
//  ScannerWindowController.m
//  MemScan
//
//  Created by Joe Savage on 28/12/2014.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#import "ScannerWindowController.h"
#import "MachAbstractions.h"

@implementation ScannerWindowController

- (id) init {
    self = [super initWithWindowNibName:@"ScannerWindow"];
    if (self) {
        _process = nil;
    }
    
    return self;
}

- (void) dealloc {
    [_process release];
    
    [super dealloc];
}

- (void) throwFatalError:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Fatal Error"];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSCriticalAlertStyle];
    
    [alert runModal];
    [alert release];
    // [self.window close];
}

- (void) handleKernReturn:(kern_return_t)error forFunction:(NSString *)function {
    if (error != KERN_SUCCESS) {
        NSString *message = [NSString stringWithFormat:@"%@ failed with message %d: %s",
                             function, error, mach_error_string(error)];
        [self throwFatalError:message];
    }
}

- (void) setProcess:(NSDictionary *)process {
    _process = [process retain];
    [self updateLabels];
}

- (void) updateLabels {
    NSString *pidString = [NSString stringWithFormat:@"%@ (%@)", [_process objectForKey:@"pid"], [_process objectForKey:@"name"]];
    [_processLabel setStringValue:pidString];
}

- (void)initiateWindowAction {
    [self.window makeKeyAndOrderFront:nil];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _task = 0;
    [self updateLabels];
}

- (void) windowWillClose:(NSNotification *)notification {
    [_process release];
    _process = nil;
}

- (IBAction) initiateScan:(id)sender {
    NSInteger pid = [[_process objectForKey:@"pid"] integerValue];
    if (pid > INT_MAX)
        [self throwFatalError:@"Invalid PID specified."];
    
    // TODO: Give the application some mechanism for requesting privs to see processes (rather than having to run as 'sudo')
    
    [self handleKernReturn:task_for_pid(mach_task_self(), (int)pid, &_task) forFunction:@"task_for_pid"];
    
    unsigned char needle[] = "\x5f\x5f\x74\x65";
    unsigned int needle_length = 4;
    search_task_memory(_task, 0x00, needle, needle_length);
}

@end
