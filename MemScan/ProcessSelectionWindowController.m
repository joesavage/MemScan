//
//  ProcessSelectionWindowController.m
//  MemScan
//
//  Created by Joe Savage on 28/12/2014.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#import "ProcessSelectionWindowController.h"

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

- (void) initiateWindowAction {
    [self.window makeKeyAndOrderFront:nil];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // This is invoked when the window this controller is controlling has been loaded from its nib
    // TODO: Window initialisation
}

@end
