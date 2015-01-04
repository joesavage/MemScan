//
//  MachAbstractions.cpp
//  MemScan
//
//  Created by Joe Savage on 30/12/14.
//  Copyright (c) 2014 Joe Savage. All rights reserved.
//

#include "MachAbstractions.h"

kern_return_t find_primary_binary_location(task_t task,
                                           vm_address_t *address_output,
                                           struct mach_header_64 *header_output)
{
    // Find a Mach-O ABI header by scanning the first bytes of each virtual memory region
    // NOTE: This function was inspired by the MachOView source
    vm_address_t addr = 0x00;
    while (1) {
        vm_size_t size;
        unsigned int depth;
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        kern_return_t error = vm_region_recurse_64(task, &addr, &size, &depth, (vm_region_info_t)&info, &count);
        if (error != KERN_SUCCESS)
            return error;
        
        struct mach_header_64 header = {0};
        vm_size_t bytes_read = 0;
        error = vm_read_overwrite(task, (mach_vm_address_t)addr,
                                  (vm_size_t)sizeof(struct mach_header_64),
                                  (vm_address_t)&header,
                                  &bytes_read);
        if (error == KERN_SUCCESS && bytes_read == sizeof(struct mach_header_64)) {
            if ((header.magic == MH_MAGIC || header.magic == MH_MAGIC_64) && header.filetype == MH_EXECUTE) {
                if (header_output != NULL)
                    *header_output = header;
                *address_output = addr;
                return KERN_SUCCESS;
            }
        }
        addr += size;
    }
    
    return KERN_FAILURE;
}

kern_return_t get_load_commands(task_t task,
                                struct mach_header_64 header,
                                vm_address_t addr,
                                unsigned char **address_output)
{
    unsigned short header_size = sizeof(struct mach_header_64);
    unsigned char *load_commands = (unsigned char *)malloc(header.sizeofcmds);
    if (load_commands == NULL)
        return KERN_RESOURCE_SHORTAGE;
    
    vm_size_t bytes_read = 0;
    kern_return_t error = vm_read_overwrite(task,
                                            addr + header_size,
                                            (vm_size_t)header.sizeofcmds,
                                            (vm_address_t)load_commands,
                                            &bytes_read);
    *address_output = load_commands;
    
    return error;
}

kern_return_t get_first_segment_with_name(task_t task,
                                          struct mach_header_64 header,
                                          vm_address_t base,
                                          char *name,
                                          struct segment_command_64 *segment_output)
{
    unsigned char *load_commands = NULL;
    kern_return_t error = get_load_commands(task, header, base, &load_commands);
    if (error != KERN_SUCCESS)
        return error;
    
    vm_address_t addr = (vm_address_t)load_commands;
    struct load_command *lc = NULL;
    for (unsigned int i = 0; i < header.ncmds; ++i) {
        lc = (struct load_command *)addr;
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *sc = (struct segment_command_64 *)addr;
            if (name == NULL || strncmp(sc->segname, name, 16) == 0) {
                if (segment_output != NULL)
                    *segment_output = *sc;
                free(load_commands);
                return KERN_SUCCESS;
            }
        }
        addr += lc->cmdsize;
    }
    
    free(load_commands);
    return KERN_FAILURE;
}

kern_return_t get_aslr_slide(task_t task,
                             struct mach_header_64 header,
                             vm_address_t base,
                             vm_address_t *aslr_slide)
{
    struct segment_command_64 segment_command;
    
    // NOTE: The location of __PAGEZERO isn't randomized (see: 'randomizeExecutableLoadAddress')
    // NOTE: This operates on the assumption that the Mach-O header and LCs are at the start of __TEXT (always the case?)
    kern_return_t error = get_first_segment_with_name(task, header, base, "__TEXT", &segment_command);
    *aslr_slide = base - segment_command.vmaddr;
    
    return error;
}

int boyer_moore(unsigned char *haystack, size_t haystack_length,
                unsigned char *needle, size_t needle_length,
                vm_address_t **results_out, size_t *results_length_out)
{
    vm_address_t *&results = *results_out;
    size_t &results_length = *results_length_out;
    
    // NOTE: For now at least, this is Boyer-Moore-Horspool.
    // This can almost certainly be made more efficient if required.
    
    if (haystack == NULL || haystack_length == 0 ||
        needle == NULL   || needle_length == 0   ||
        needle_length > haystack_length)
        return 0;
    
    size_t results_size = BOYER_MOORE_ALLOCATION_ALIGNMENT;
    if (results == NULL || results_length == 0) {
        results = (size_t *)malloc(sizeof(size_t) * results_size);
        if (results == NULL)
            return 0;
    } else {
        results_size = results_length;
    }
    
    // Preprocess the needle into a skip table for faster searching
    size_t skip_table[256] = {};
    for (size_t i = 0; i < sizeof(skip_table) / sizeof(size_t); ++i)
        skip_table[i] = needle_length;
    for (size_t i = 0; i < needle_length - 1; ++i)
        skip_table[needle[i]] = needle_length - (i + 1);
    
    // Actually perform the search!
    unsigned char *search = haystack;
    size_t number_of_results = 0;
    while (search + needle_length <= haystack + haystack_length) {
        unsigned char *mismatch = NULL;
        for (size_t it = 0; it < needle_length; ++it) {
            size_t i = needle_length - (it + 1);
            if (needle[i] != search[i]) {
                mismatch = search + i;
                break;
            }
        }
        
        if (mismatch == NULL) {
            if (number_of_results + 1 > results_size) {
                size_t *old_results = results;
                size_t old_results_size = results_size;
                
                results_size += BOYER_MOORE_ALLOCATION_ALIGNMENT;
                results = (size_t *)malloc(sizeof(size_t) * results_size);
                if (results == NULL) {
                    free(old_results);
                    return 0;
                }
                memcpy(results, old_results, sizeof(size_t) * old_results_size);
                
                free(old_results);
            }
            results[number_of_results++] = search - haystack;
            ++search;
        } else {
            search += skip_table[*mismatch];
        }
    }
    
    results_length = number_of_results;
    return number_of_results > 0;
}

