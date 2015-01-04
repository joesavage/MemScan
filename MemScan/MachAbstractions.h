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

// TODO: Remove this 'math.h' dependency
#include <math.h>

#ifndef MemScan_MachAbstractions_h
#define MemScan_MachAbstractions_h

#define BOYER_MOORE_ALLOCATION_ALIGNMENT 128

kern_return_t find_primary_binary_location(task_t task,
                                           vm_address_t *address_output,
                                           struct mach_header_64 *header_output);

// NOTE: This allocates on the heap and the caller should free the memory
kern_return_t get_load_commands(task_t task,
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

int generate_boyer_moore_skip_table(unsigned char *needle, size_t needle_length, size_t *skip_table_out);

// NOTE: This can allocate on the heap and the caller should free the memory
int boyer_moore(unsigned char *haystack, size_t haystack_length,
                unsigned char *needle, size_t needle_length, size_t *skip_table,
                vm_address_t **results_out, size_t *results_length_out);

// NOTE: This can allocate on the heap and the caller should free the memory
int boyer_moore(unsigned char *haystack, size_t haystack_length,
                unsigned char *needle, size_t needle_length,
                vm_address_t **results_out, size_t *results_length_out);

#endif
