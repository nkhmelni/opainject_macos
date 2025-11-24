# opainject_macos

A dynamic library injection tool for macOS using Return-Oriented Programming (ROP) techniques to inject dylibs into running processes.

## Attribution

This project is a macOS port of [opainject](https://github.com/opa334/opainject) by Lars Fröder (opa334), originally developed for iOS. The core ROP injection methodology and architecture handling are derived from the original implementation.

**macOS port by:** [@nkhmelni](https://github.com/nkhmelni)

**Key adaptations:**
- The `get_task_by_pid()` function implements the processor set enumeration technique documented by Jonathan Levin in [PST2: Doing It Again](https://newosxbook.com/articles/PST2.html), enabling task port acquisition without requiring `task_for_pid()` or private entitlements on macOS.
- Build system migrated from Makefile to CMake for convenience.
- Shellcode injection method removed; this implementation uses ROP injection exclusively.

## Overview

opainject_macos enables runtime dylib injection into arbitrary processes by leveraging ROP chains to execute `dlopen()` within the target process's address space. The tool creates a controlled pthread in the target, manipulates thread state to perform arbitrary function calls, and handles sandbox restrictions when necessary.

**Supported architectures:** ARM64, ARM64e

## Features

- **ROP-based injection:** No executable memory allocation required; uses existing code gadgets
- **Universal binary support:** Automatically detects and matches target process architecture (arm64/arm64e)
- **ARM64e PAC handling:** Properly signs function pointers for Pointer Authentication compatibility
- **Sandbox bypass:** Automatically issues and consumes sandbox extensions when needed

## Requirements

- macOS 11.0 or later
- ARM64 or ARM64e processor
- Root privileges (sudo)
- The target executable's architecture must match the injected dylib's architecture. Both must be either arm64 or arm64e.

**Important:** System Integrity Protection (SIP) may need to be disabled for the processor set enumeration technique to succeed, particularly when targeting hardened runtime binaries. Alternatively, the implementation can be modified to use `task_for_pid()`, which requires the `com.apple.security.cs.debugger` entitlement but only functions on user binaries (not system or App Store binaries).

## Building

The project uses CMake and produces a universal binary with arm64 and arm64e slices.

```bash
mkdir build
cd build
cmake ..
make
```

The compiled binary will be located at `build/opainject` and will be automatically code-signed (ad-hoc) with the included entitlements.

## Usage

```bash
sudo ./opainject <pid> /path/to/dylib
```

**Parameters:**
- `<pid>` — Process identifier of the target process
- `/path/to/dylib` — Absolute or relative path to the dynamic library to inject

## Technical Details

**Injection Method:** ROP-only (Return-Oriented Programming)

The injection process uses an infinite loop gadget (`b .` instruction, opcode `0x00000014`) as a synchronization primitive. A new pthread is created in the target process that executes at this gadget, allowing controlled thread state manipulation to perform arbitrary function calls including `dlopen()`, `sandbox_extension_consume()`, and others.

**Task Port Acquisition:** Processor set enumeration technique (PST2)

Rather than using `task_for_pid()` directly, the tool enumerates all tasks via the processor set control port, matching by PID. This approach functions without requiring private entitlements, though it may require SIP to be disabled depending on the target process's hardening configuration.

## License

MIT License

Copyright (c) 2022 Lars Fröder (original iOS implementation)
Copyright (c) 2025 Nikita Hmelnitkii (macOS port)

See [LICENSE](LICENSE) for the complete license text.

This derivative work maintains the same permissive MIT License terms as the original [opainject](https://github.com/opa334/opainject) project.
