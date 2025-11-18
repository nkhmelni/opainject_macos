cmake_minimum_required(VERSION 3.20)
project(opainject_macos C)

# Enable Objective-C
enable_language(OBJC)

# Set architectures to both arm64 and arm64e (universal binary)
set(CMAKE_OSX_ARCHITECTURES "arm64;arm64e")

# Set deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0")

# Create executable
add_executable(opainject
    main.m
    dyld.m
    rop_inject.m
    thread_utils.m
    task_utils.m
    arm64.m
)

# Compiler flags
target_compile_options(opainject PRIVATE
    -fobjc-arc
    -Wno-deprecated-declarations
)

# Link frameworks
target_link_libraries(opainject "-framework CoreFoundation")

# Code signing with entitlements
add_custom_command(TARGET opainject POST_BUILD
    COMMAND codesign -s - --entitlements ${CMAKE_CURRENT_SOURCE_DIR}/entitlements.plist --force $<TARGET_FILE:opainject>
    COMMENT "Signing with entitlements"
)
