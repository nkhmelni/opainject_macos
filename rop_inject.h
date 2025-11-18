#ifndef ROP_INJECT_H
#define ROP_INJECT_H

extern void injectDylibViaRop(task_t task, pid_t pid, const char* dylibPath, vm_address_t allImageInfoAddr);

#endif /* ROP_INJECT_H */