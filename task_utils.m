#import <mach/mach.h>
#import <stdlib.h>

kern_return_t task_read(task_t task, vm_address_t address, void *outBuf, vm_size_t size)
{
	size_t maxSize = size;
	kern_return_t kr = vm_read_overwrite(task, address, size, (vm_address_t)outBuf, &maxSize);
	if (kr == KERN_SUCCESS) {
		if (maxSize < size) {
			uint8_t *outBufU = outBuf;
			memset(&outBufU[maxSize-1], 0, size - maxSize);
		}
	}
	return kr;
}

char *task_copy_string(task_t task, vm_address_t address)
{
	size_t len = 0;
	char buf = 0;
	do {
		if (task_read(task, address + (len++), &buf, sizeof(buf)) != KERN_SUCCESS) return NULL;
	} while (buf != '\0');

	// copy string
	char *strBuf = malloc(len);
	if (task_read(task, address, &strBuf[0], len) != KERN_SUCCESS) return NULL;
	return strBuf;
}

kern_return_t task_write(task_t task, vm_address_t address, void* inBuf, vm_size_t size)
{
	return vm_write(task, address, (vm_offset_t)inBuf, size);
}

task_t get_task_by_pid(pid_t pid)
{
	task_port_t psDefault;
	task_port_t psDefault_control;
	task_array_t tasks;
	mach_msg_type_number_t numTasks;
	kern_return_t kr;
	host_t self_host = mach_host_self();
	kr = processor_set_default(self_host, &psDefault);
	if (kr != KERN_SUCCESS)
		return MACH_PORT_NULL;
	kr = host_processor_set_priv(self_host, psDefault, &psDefault_control);
	if (kr != KERN_SUCCESS)
		return MACH_PORT_NULL;
	kr = processor_set_tasks(psDefault_control, &tasks, &numTasks);
	if (kr != KERN_SUCCESS)
		return MACH_PORT_NULL;

	for (int i = 0; i < numTasks; i++)
	{
		int task_pid;
		kr = pid_for_task(tasks[i], &task_pid);
		if (kr != KERN_SUCCESS)
			continue;
		if (task_pid == pid)
			return tasks[i];
	}
	return MACH_PORT_NULL;
}