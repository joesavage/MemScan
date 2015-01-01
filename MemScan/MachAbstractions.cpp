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

kern_return_t get_load_commands_on_heap(task_t task,
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
    kern_return_t error = get_load_commands_on_heap(task, header, base, &load_commands);
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

kern_return_t search_for_bytes_in_buffer(unsigned char *needle, size_t needlesize,
                                         unsigned char *buffer, size_t buffersize,
                                         vm_address_t **results_out, size_t *number_of_results_out)
{
    vm_address_t *&results = *results_out;
    size_t &number_of_results = *number_of_results_out;
    
    // TODO: Improve the memory management model here, don't limit to 100, etc.
    results = (vm_address_t *)malloc(sizeof(vm_address_t) * 100);
    if (results == NULL)
        return KERN_RESOURCE_SHORTAGE;
    number_of_results = 0;
    
    // TODO: Improve searching algorithm (Boyer-Moore?)
    for (size_t i = 0; i < buffersize; ++i) {
        bool match = true;
        
        for (size_t j = 0; j < needlesize; ++j) {
            if (i + j > buffersize || needle[j] != buffer[i + j])
                match = false;
        }
        
        if (match && number_of_results < 100)
            results[number_of_results++] = i;
    }
    
    return KERN_SUCCESS;
}
