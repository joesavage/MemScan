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
    
    {
        kern_return_t error = task_for_pid(mach_task_self(), (int)pid, &_task);
        if (error != KERN_SUCCESS) {
            [self throwFatalError:[NSString stringWithFormat:@"task_for_pid failed with message %d: %s",
                                   error, mach_error_string(error)]];
        }
    }
    
    
    vm_address_t base;
    struct mach_header_64 header;
    {
        // TODO: Modularise this kern_return_t error handling procedure
        kern_return_t error = find_primary_binary_location(_task, &base, &header);
        if (error != KERN_SUCCESS)
            [self throwFatalError:@"find_primary_binary_location"];
    }
    
    vm_address_t aslr_slide;
    {
        kern_return_t error = get_aslr_slide(_task, header, base, &aslr_slide);
        if (error != KERN_SUCCESS)
            [self throwFatalError:@"get_aslr_slide"];
    }
    
    struct segment_command_64 segment;
    {
        kern_return_t error = get_first_segment_with_name(_task, header, base, "__LINKEDIT", &segment);
        if (error != KERN_SUCCESS)
            [self throwFatalError:@"get_first_segment_with_name"];
    }
    
    unsigned char data[100] = {0};
    vm_size_t bytes_read;
    {
        kern_return_t error = vm_read_overwrite(_task, aslr_slide + segment.vmaddr, 100, (vm_address_t)&data, &bytes_read);
        if (error != KERN_SUCCESS)
            [self throwFatalError:@"vm_read_overwrite"];
    }
    
    for (vm_size_t i = 0; i < 100; ++i) {
        printf("%02x", (int)data[i]);
    }
}

@end
