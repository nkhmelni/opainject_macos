#ifndef TASK_UTILS_H
#define TASK_UTILS_H

#include <mach/mach.h>
#include <sys/types.h>

kern_return_t task_read(task_t task, vm_address_t address, void *outBuf, vm_size_t size);
char *task_copy_string(task_t task, vm_address_t address);
kern_return_t task_write(task_t task, vm_address_t address, void* inBuf, vm_size_t size);
task_t get_task_by_pid(pid_t pid);

#endif /* TASK_UTILS_H */