//
//  MachAbstractions.h
//  MemScan
//
//  Created by Joe Savage on 30/12/14.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach-o/loader.h>

#ifndef MemScan_MachAbstractions_h
#define MemScan_MachAbstractions_h

kern_return_t find_primary_binary_location(task_t task,
                                           vm_address_t *address_output,
                                           struct mach_header_64 *header_output);
kern_return_t get_load_commands_on_heap(task_t task,
                                        struct mach_header_64 header,
                                        vm_address_t addr,
                                        unsigned char **address_output);
kern_return_t get_first_segment_with_name(task_t task,
                                          struct mach_header_64 header,
                                          vm_address_t base,
                                          char *name,
                                          struct segment_command_64 *segment_output);
kern_return_t get_aslr_slide(task_t task,
                             struct mach_header_64 header,
                             vm_address_t base,
                             vm_address_t *aslr_slide);

#endif
