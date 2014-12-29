//
//  ProcessSelectionWindowController.h
//  MemScan
//
//  Created by Joe Savage on 28/12/2014.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ProcessSelectionWindowController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>
{
             NSArray     *_processes;
    IBOutlet NSButton    *_selectButton;
    IBOutlet NSButton    *_refreshButton;
    IBOutlet NSTableView *_processTableView;
}

- (id) init;
- (void) dealloc;

- (void) initiateWindowAction;
- (void) windowDidLoad;
- (void) windowWillClose:(NSNotification *)notification;

- (IBAction) reloadProcessTableData:(id)sender;

- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView;

@end
