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
        _scanResults = {};
    }
    
    return self;
}

- (void) dealloc {
    [_process release];
    free(_scanResults.results);
    
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

- (void) updateLabels { // TODO: Rename or remove? This only updates one label right now!
    NSString *pidString = [NSString stringWithFormat:@"%@ (%@)", [_process objectForKey:@"pid"], [_process objectForKey:@"name"]];
    [_processLabel setStringValue:pidString];
}

- (void)initiateWindowAction {
    [self.window makeKeyAndOrderFront:nil];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _task = 0;
    [_scanTypeComboBox addItemsWithObjectValues:@[@"Exact Value", @"Value Greater Than", @"Value Less Than", @"Unknown Initial Value"]];
    [_dataTypeComboBox addItemsWithObjectValues:@[@"1 Byte", @"2 Byte", @"4 Byte", @"8 Byte", @"Float", @"Double", @"All Numerical Types", @"Binary", @"Hex", @"String"]];
    [self updateLabels];
}

- (void) windowWillClose:(NSNotification *)notification {
    [_process release];
    _process = nil;
    free(_scanResults.results);
    _scanResults = {};
}

- (kern_return_t) searchProcessMemory:(task_t)task
                                 from:(vm_address_t)address
                            forNeedle:(unsigned char *)needle
                           withLength:(size_t)needle_length
{
    size_t skip_table[256] = {};
    if (!generate_boyer_moore_skip_table(needle, needle_length, skip_table))
        return KERN_SUCCESS;
    
    _scanResults.count = 0;
    if (_scanResults.results == NULL) {
        _scanResults.size = 128;
        _scanResults.results = (ScanResult *)malloc(sizeof(_scanResults.results[0]) * _scanResults.size);
        if (_scanResults.results == NULL) {
            _scanResults.size = 0;
            return KERN_RESOURCE_SHORTAGE;
        }
    }
    
    size_t minimum_address = SIZE_MAX;
    size_t maximum_address = 0;
    size_t result_count = 0;
    
    size_t buffsize = 128 * getpagesize();
    unsigned char *buffer = (unsigned char *)malloc(buffsize);
    size_t transient_data_size = 256;
    size_t *transient_data = (size_t *)malloc(sizeof(size_t) * transient_data_size);
    if (buffer == NULL || transient_data == NULL)
        return KERN_RESOURCE_SHORTAGE;
    
    while (true) {
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        vm_size_t size;
        mach_port_t object_name;
        kern_return_t error = vm_region_64(task, &address, &size,
                                           VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &count, &object_name);
        if (error != KERN_SUCCESS)
            break;
        
        // Scan from 'addr' to 'address + size'
        vm_address_t destination = address + size;
        while (address < destination) {
            vm_size_t chunksize = buffsize;
            if (destination - address < chunksize)
                chunksize = destination - address;
            
            vm_size_t bytes_read = 0;
            kern_return_t error = vm_read_overwrite(task, address, chunksize, (vm_address_t)buffer, &bytes_read);
            if (error != KERN_PROTECTION_FAILURE && error != KERN_INVALID_ADDRESS) {
                if (error != KERN_SUCCESS)
                    return error;
                
                // NOTE: We currently don't scan for data spanning over chunk boundaries. If this becomes an issue, you can
                // simply create a buffer storing the N-1 bytes from the last chunk, and include those in the scan process.
                
                size_t results_length = transient_data_size;
                if (boyer_moore((unsigned char *)buffer, bytes_read,
                                (unsigned char *)needle, needle_length, skip_table,
                                &transient_data, &results_length))
                {
                    if (results_length > transient_data_size) {
                        size_t blocks_allocated = floorl(((double)results_length / BOYER_MOORE_ALLOCATION_ALIGNMENT) + 0.5);
                        transient_data_size = BOYER_MOORE_ALLOCATION_ALIGNMENT * blocks_allocated;
                    }
                    
                    // TODO: Update the NSProgressIndicator
                    
                    // Perform the intended operations on these set of results
                    for (size_t i = 0; i < results_length; ++i) {
                        size_t result_address = address + transient_data[i];
                        
                        // TODO: Having the memory allocation unabstracted right here in with app logic seems messy.
                        if (result_count + 1 >= _scanResults.size) {
                            ScanResult *oldResults = _scanResults.results;
                            _scanResults.size *= 2;
                            _scanResults.results = (ScanResult *)malloc(sizeof(_scanResults.results[0]) * _scanResults.size);
                            if (!_scanResults.results)
                                return KERN_RESOURCE_SHORTAGE;
                            memcpy(_scanResults.results, oldResults, result_count * sizeof(_scanResults.results[0]));
                            free(oldResults);
                        }
                        _scanResults.results[result_count].address = result_address;
                        for (unsigned short j = 0; j < 8; ++j)
                            _scanResults.results[result_count].value[j] = (buffer + transient_data[i])[j];
                        
                        if (address + transient_data[i] < minimum_address)
                            minimum_address = result_address;
                        if (address + transient_data[i] > maximum_address)
                            maximum_address = result_address;
                        
                        ++result_count;
                    }
                }
            }
            
            address += chunksize;
        }
        
        if (address == 0)
            break;
    }
    
    _scanResults.count = result_count;
    free(transient_data);
    free(buffer);
    
    // TODO: Should these live in here? I'm not sure.
    NSString *resultRangeString = nil;
    resultRangeString = result_count == 0 ? @"N/A"
    : [NSString stringWithFormat:@"%08lx - %08lx", minimum_address, maximum_address];
    [_resultRangeLabel setStringValue:resultRangeString];
    [_numberOfResultsLabel setStringValue:[NSString stringWithFormat:@"%lu", _scanResults.count]];
    [_resultsTableView reloadData];
    
    return KERN_SUCCESS;
}

- (IBAction) initiateScan:(id)sender {
    NSInteger pid = [[_process objectForKey:@"pid"] integerValue];
    if (pid > INT_MAX)
        [self throwFatalError:@"Invalid PID specified."];
    
    // TODO: Give the application some mechanism for requesting privs to see processes (rather than having to run as 'sudo')
    
    [self handleKernReturn:task_for_pid(mach_task_self(), (int)pid, &_task) forFunction:@"task_for_pid"];
    
    // TODO: Add scan state (first scan, next scan, etc.)
    
    // TODO: Scan for the specified value rather than this constant
    unsigned char needle[] = "\x5f\x5f\x74\x65";
    unsigned int needle_length = 4;
    [self searchProcessMemory:_task from:0x00 forNeedle:needle withLength:needle_length];
}

- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    NSString *resultString = nil;
    
    if ([tableColumn.identifier isEqualToString:@"address"]) {
        size_t address = _scanResults.results[row].address;
        resultString = [NSString stringWithFormat:@"%08lx", address];
    } else if ([tableColumn.identifier isEqualToString:@"value"]) {
        // TODO: Deal with typing this properly
        // TODO: These values probably should probably update and not stay around to get stale!
        unsigned char value = _scanResults.results[row].value[0];
        resultString = [NSString stringWithFormat:@"%d", (int)value];
    }
    
    result.textField.stringValue = resultString;
    return result;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    if (_scanResults.results != NULL)
        return _scanResults.count;
    return 0;
}

@end
