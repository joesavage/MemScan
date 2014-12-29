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
#include <pwd.h>

@implementation ProcessSelectionWindowController

- (id) init {
    self = [super initWithWindowNibName:@"ProcessSelectionWindow"];
    if (self) {
        _processes = nil;
    }
    
    return self;
}

- (void) dealloc {
    [_processes release];
    
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
    // NOTE: Could probably use 'proc_listpids' here instead of 'sysctl'
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
            
            uid_t uid = processInfo[i].kp_eproc.e_pcred.p_ruid;
            char *uname = getpwuid(uid)->pw_name;
            NSString *name = [NSString stringWithCString:processName encoding:NSUTF8StringEncoding];
            NSString *user = [NSString stringWithCString:uname encoding:NSUTF8StringEncoding];
            [processes addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSNumber numberWithInt:pid], @"pid",
                                                    user, @"user",
                                                    name, @"name",
                                                    nil]];
        }
    }
    
    free(processInfo);
    return processes;
}

- (void) initiateWindowAction {
    [self.window makeKeyAndOrderFront:nil];
    [self reloadProcessTableData:nil];
}

// This is invoked when the window this controller is controlling has been loaded from its nib
- (void)windowDidLoad {
    [super windowDidLoad];
    
    _processes = [ProcessSelectionWindowController getAllProcesses];
}

- (void) windowWillClose:(NSNotification *)notification {
    [_processes release];
    _processes = nil;
}

- (IBAction) reloadProcessTableData:(id)sender {
    _processes = [[ProcessSelectionWindowController getAllProcesses] retain];
    [_processTableView reloadData];
}

- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    NSString *resultString = nil;
    resultString = [NSString stringWithFormat:@"%@", [[_processes objectAtIndex:row] valueForKey:tableColumn.identifier]];
    
    result.textField.stringValue = resultString;
    return result;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    if (_processes != nil)
        return [_processes count];
    return 0;
}

@end
