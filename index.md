---
layout: default
title: opainject_macos - macOS Dylib Injection Tool
---

# opainject_macos

Dynamic library injection tool for macOS using Return-Oriented Programming (ROP) techniques.

---

## Download

[**Latest Release**](https://github.com/nkhmelni/opainject_macos/releases) · [**Source Code**](https://github.com/nkhmelni/opainject_macos)

---

## Usage

```bash
sudo ./opainject <pid> /path/to/dylib
```

Injects a dynamic library into a running process by process ID.

---

## Features

- **ROP-based injection** - No executable memory allocation required
- **ARM64/ARM64e support** - Universal binary with Pointer Authentication Code handling
- **Automatic architecture matching** - Detects and adapts to target process architecture
- **Sandbox bypass** - Handles sandbox restrictions automatically

---

## Requirements

- macOS 11.0 or later
- ARM64/ARM64e processor
- Root privileges (sudo)
- SIP may need to be disabled for hardened runtime targets

**Note:** Target executable architecture must match dylib architecture.

---

## Documentation

Complete documentation, build instructions, and technical details available in the [GitHub repository](https://github.com/nkhmelni/opainject_macos).

---

## Attribution

**macOS port by:** [@nkhmelni](https://github.com/nkhmelni)

**Based on:** [opainject](https://github.com/opa334/opainject) by Lars Fröder (opa334)

**Task port acquisition technique:** Jonathan Levin's [PST2: Doing It Again](https://newosxbook.com/articles/PST2.html)

---

## License

[MIT License](https://github.com/nkhmelni/opainject_macos/blob/main/LICENSE)

Copyright (c) 2022 Lars Fröder · Copyright (c) 2025 Nikita Hmelnitkii
