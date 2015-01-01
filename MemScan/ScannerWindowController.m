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
    
    {
        vm_address_t addr = 0x00;
        unsigned int buffsize = 128 * getpagesize();
        unsigned char *buffer = (unsigned char *)malloc(buffsize);
        while (true) {
            vm_region_basic_info_data_64_t info;
            mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
            vm_size_t size;
            mach_port_t object_name;
            kern_return_t error = vm_region_64(_task, &addr, &size, VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &count, &object_name);
            if (error != KERN_SUCCESS)
                break;
            
            // Scan from 'addr' to 'addr + size'
            vm_address_t destination = addr + size;
            while (addr < destination) {
                vm_size_t chunksize = buffsize;
                if (destination - addr < chunksize)
                    chunksize = destination - addr;
                
                vm_size_t bytes_read = 0;
                kern_return_t error = vm_read_overwrite(_task, addr, chunksize, (vm_address_t)buffer, &bytes_read);
                if (error == KERN_PROTECTION_FAILURE || error == KERN_INVALID_ADDRESS)
                    goto step;
                else
                    [self handleKernReturn:error forFunction:@"vm_read_overwrite"];
                
                // NOTE: We currently don't scan for data spanning over chunk boundaries. If this becomes an issue, you can
                // simply create a buffer storing the N-1 bytes from the last chunk, and include those in the scan process.
                
                // TODO: Would be good to move this in-loop allocation outside the loop (to a memory block with a default large size
                // that increases only if required)
                {
                    unsigned char needle[] = "\x5f\x5f\x74\x65"; // TODO: Set properly
                    unsigned int needlesize = 4;
                    vm_address_t *results = NULL;
                    size_t number_of_results = 0;
                    search_for_bytes_in_buffer(needle, needlesize, buffer, bytes_read, &results, &number_of_results);
                    
                    for (unsigned long i = 0; i < number_of_results; ++i)
                        printf("%08lx\n", addr + results[i]);
                    
                    free(results);
                }
                
                // TODO: Could print information about the region in which the data was found, etc.
                
            step:
                addr += chunksize;
            }
            
            if (addr == 0)
                break;
        }
        free(buffer);
    }
}

@end
