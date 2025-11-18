#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <string.h>
#import <limits.h>
#import <spawn.h>
#import <libproc.h>
#import "dyld.h"
#import "rop_inject.h"
#import "task_utils.h"

// Detect if target process is arm64e
bool isTargetArm64e(pid_t pid)
{
	char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
	if (proc_pidpath(pid, pathbuf, sizeof(pathbuf)) <= 0) {
		printf("[isTargetArm64e] Failed to get path for pid %d\n", pid);
		return false;
	}

	FILE *f = fopen(pathbuf, "rb");
	if (!f) {
		printf("[isTargetArm64e] Failed to open %s\n", pathbuf);
		return false;
	}

	uint32_t magic;
	if (fread(&magic, sizeof(magic), 1, f) != 1) {
		fclose(f);
		return false;
	}

	fseek(f, 0, SEEK_SET);

	if (magic == FAT_MAGIC || magic == FAT_CIGAM || magic == FAT_MAGIC_64 || magic == FAT_CIGAM_64) {
		struct fat_header fh;
		fread(&fh, sizeof(fh), 1, f);
		uint32_t nfat = OSSwapBigToHostInt32(fh.nfat_arch);

		for (uint32_t i = 0; i < nfat; i++) {
			struct fat_arch fa;
			fread(&fa, sizeof(fa), 1, f);
			uint32_t cputype = OSSwapBigToHostInt32(fa.cputype);
			uint32_t cpusubtype = OSSwapBigToHostInt32(fa.cpusubtype);

			if (cputype == CPU_TYPE_ARM64 && (cpusubtype & ~CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64E) {
				fclose(f);
				return true;
			}
		}
	}
	else if (magic == MH_MAGIC_64 || magic == MH_CIGAM_64) {
		struct mach_header_64 mh;
		fseek(f, 0, SEEK_SET);
		fread(&mh, sizeof(mh), 1, f);
		fclose(f);

		if (mh.cputype == CPU_TYPE_ARM64 && (mh.cpusubtype & ~CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64E) {
			return true;
		}
	}

	fclose(f);
	return false;
}

char* resolvePath(char* pathToResolve)
{
	if(strlen(pathToResolve) == 0) return NULL;
	if(pathToResolve[0] == '/')
	{
		return strdup(pathToResolve);
	}
	else
	{
		char absolutePath[PATH_MAX];
		if (realpath(pathToResolve, absolutePath) == NULL) {
			perror("[resolvePath] realpath");
			return NULL;
		}
		return strdup(absolutePath);
	}
}

static char* getExecutablePath(void)
{
	uint32_t size = 0;
	_NSGetExecutablePath(NULL, &size);
	char *path = malloc(size);
	if (path) {
		_NSGetExecutablePath(path, &size);
	}
	return path;
}

extern int posix_spawnattr_set_ptrauth_task_port_np(posix_spawnattr_t * __restrict attr, mach_port_t port);
void spawnPacChild(int argc, char *argv[])
{
	char** argsToPass = malloc(sizeof(char*) * (argc + 2));
	for(int i = 0; i < argc; i++)
	{
		argsToPass[i] = argv[i];
	}
	argsToPass[argc] = "pac";
	argsToPass[argc+1] = NULL;

	pid_t targetPid = atoi(argv[1]);
	mach_port_t task;
	task = get_task_by_pid(targetPid);
	if(task == MACH_PORT_NULL) {
		printf("[spawnPacChild] Failed to obtain task port.\n");
		return;
	}
	printf("[spawnPacChild] Got task port %d for pid %d\n", task, targetPid);

	posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
	posix_spawnattr_set_ptrauth_task_port_np(&attr, task);

	char *executablePath = getExecutablePath();

	int status = -200;
	pid_t pid;
	int rc = posix_spawn(&pid, executablePath, NULL, &attr, argsToPass, NULL);

	posix_spawnattr_destroy(&attr);
	free(argsToPass);
	free(executablePath);

	if(rc != KERN_SUCCESS)
	{
		printf("[spawnPacChild] posix_spawn failed: %d (%s)\n", rc, mach_error_string(rc));
		return;
	}

	do
	{
		if (waitpid(pid, &status, 0) != -1) {
			printf("[spawnPacChild] Child returned %d\n", WEXITSTATUS(status));
		}
	} while (!WIFEXITED(status) && !WIFSIGNALED(status));

	return;
}

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool
	{
		setlinebuf(stdout);
		setlinebuf(stderr);
		if (argc < 3 || argc > 4)
		{
			printf("Usage: opainject <pid> <path/to/dylib>\n");
			return -1;
		}

		pid_t targetPid = atoi(argv[1]);

		// Detect target architecture at runtime
		bool targetIsArm64e = isTargetArm64e(targetPid);
		printf("[main] Target PID %d is %s\n", targetPid, targetIsArm64e ? "arm64e" : "arm64");

#ifdef __arm64e__
		// We're running as arm64e slice
		if (targetIsArm64e) {
			// Target is arm64e - need PAC child
			char* pacArg = NULL;
			if(argc >= 4)
			{
				pacArg = argv[3];
			}
			if (!pacArg || (strcmp("pac", pacArg) != 0))
			{
				spawnPacChild(argc, argv);
				return 0;
			}
		}
#else
		// We're running as arm64 slice
		if (targetIsArm64e) {
			// Target is arm64e but we're arm64 - need to respawn as arm64e
			printf("[main] Target is arm64e, but injector is arm64. Re-executing as arm64e...\n");

			char *executablePath = getExecutablePath();
			posix_spawnattr_t attr;
			posix_spawnattr_init(&attr);

			cpu_type_t cpu_types[] = {CPU_TYPE_ARM64};
			size_t cpu_count = 1;
			cpu_types[0] = (CPU_TYPE_ARM64 | CPU_SUBTYPE_ARM64E);
			posix_spawnattr_setbinpref_np(&attr, 1, cpu_types, &cpu_count);

			pid_t pid;
			int rc = posix_spawn(&pid, executablePath, NULL, &attr, argv, NULL);
			posix_spawnattr_destroy(&attr);
			free(executablePath);

			if(rc != 0)
			{
				printf("[main] Failed to respawn as arm64e: %d (%s)\n", rc, strerror(rc));
				return -1;
			}

			int status;
			waitpid(pid, &status, 0);
			return WEXITSTATUS(status);
		}
		// If target is arm64, continue normally
#endif

		printf("OPAINJECT HERE WE ARE\n");
		printf("RUNNING AS %d\n", getuid());

		task_t procTask = MACH_PORT_NULL;
		char* dylibPath = resolvePath(argv[2]);
		if(!dylibPath) return -3;
		if(access(dylibPath, R_OK) < 0)
		{
			printf("ERROR: Can't access passed dylib at %s\n", dylibPath);
			return -4;
		}

		// get task port
		procTask = get_task_by_pid(targetPid);
		if(procTask == MACH_PORT_NULL)
		{
			printf("ERROR: get_task_by_pid failed to obtain task port\n");
			return -2;
		}
		if(!MACH_PORT_VALID(procTask))
		{
			printf("ERROR: Got invalid task port (%d)\n", procTask);
			return -3;
		}

		printf("Got task port %d for pid %d!\n", procTask, targetPid);

		// get aslr slide
		task_dyld_info_data_t dyldInfo;
		uint32_t count = TASK_DYLD_INFO_COUNT;
		task_info(procTask, TASK_DYLD_INFO, (task_info_t)&dyldInfo, &count);

		injectDylibViaRop(procTask, targetPid, dylibPath, dyldInfo.all_image_info_addr);

		mach_port_deallocate(mach_task_self(), procTask);

		return 0;
	}
}
