//
//  ScannerWindowController.h
//  MemScan
//
//  Created by Joe Savage on 28/12/2014.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ScannerWindowController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>
{
             task_t         _task;
             NSDictionary   *_process;
             NSMutableArray *_scanResults;
    IBOutlet NSButton       *_scanButton;
    IBOutlet NSTextField    *_processLabel;
    IBOutlet NSTextField    *_numberOfResultsLabel;
    IBOutlet NSTextField    *_resultRangeLabel;
    IBOutlet NSComboBox     *_scanTypeComboBox;
    IBOutlet NSComboBox     *_dataTypeComboBox;
    IBOutlet NSTableView    *_resultsTableView;
    IBOutlet NSTableView    *_savedAddressTableView;
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

- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView;

@end
