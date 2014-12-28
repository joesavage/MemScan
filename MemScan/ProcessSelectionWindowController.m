//
//  ProcessSelectionWindowController.m
//  MemScan
//
//  Created by Joe Savage on 28/12/2014.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#import "ProcessSelectionWindowController.h"
#import <sys/sysctl.h>
#include <libproc.h>

@implementation ProcessSelectionWindowController

- (id) init {
    self = [super initWithWindowNibName:@"ProcessSelectionWindow"];
    if (self) {
        // TODO: nil out any custom-usage pointers for initialisation
    }
    
    return self;
}

- (void) dealloc {
    // TODO: Release any memory that we allocate
    [super dealloc];
}

+ (NSArray *) getAllProcesses {
    // 'Management Information Base' for passing to 'sysctl' calls
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    
    // Get number of processes
    size_t numberOfProcesses;
    if (sysctl(mib, 4, NULL, &numberOfProcesses, NULL, 0) == -1)
        return nil;
    
    // Get information on all processes into 'processInfo'
    struct kinfo_proc *processInfo = malloc(numberOfProcesses);
    if (!processInfo)
        return nil;
    if (sysctl(mib, 4, processInfo, &numberOfProcesses, NULL, 0) == -1) {
        free(processInfo);
        return nil;
    }
    
    // Loop through processes
    NSMutableArray *processes = [NSMutableArray array];
    size_t count = numberOfProcesses / sizeof(struct kinfo_proc);
    for (size_t i = 0; i < count; ++i) {
        pid_t pid = processInfo[i].kp_proc.p_pid;
        if (pid == 0) // Skip PID 0
            continue;
        
        char processPath[PATH_MAX];
        if (proc_pidpath(pid, processPath, sizeof(processPath))) {
            char *processName = strrchr(processPath, '/');
            if (processName)
                processName++; // Skip the '/' character
            else
                processName = processPath;
            
            NSString* name = [NSString stringWithCString:processName encoding:NSUTF8StringEncoding];
            [processes addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSNumber numberWithInt:pid], @"pid",
                                                    name, @"name",
                                                    nil]];
        }
    }
    
    free(processInfo);
    return processes;
}

- (void) initiateWindowAction {
    [self.window makeKeyAndOrderFront:nil];
}

// This is invoked when the window this controller is controlling has been loaded from its nib
- (void)windowDidLoad {
    [super windowDidLoad];
    
    // TODO: Window initialisation
    NSArray *processes = [ProcessSelectionWindowController getAllProcesses];
    for (id object in processes) {
        NSLog(@"%@", object);
    }
}

@end
