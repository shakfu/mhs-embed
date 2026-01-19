# PKG Implementation Status

## Overview

This document tracks the implementation of .pkg-based standalone binary support for mhs-embed.

## Status: COMPLETE

All four standalone variants now work correctly:
- `example-src` - source embedding
- `example-src-zstd` - source + zstd compression
- `example-pkg` - package embedding (fast startup)
- `example-pkg-zstd` - package + zstd (smallest + fast startup)

## Root Cause of Initial Failure

The pkg variants were failing with errors like:
```
undefined value: Example.init
```

### Actual Root Cause: MicroHs Cache Location Conflict

The issue was that MicroHs caches compiled modules in `.mhscache` **in the current working directory**. When the CMake build ran `mhs -P` from `WORKING_DIRECTORY ${MHS_DIR}` (thirdparty/MicroHs), it was potentially conflicting with MicroHs's own development cache and experiencing stale data.

### The Fix

Changed the build to run from `CMAKE_SOURCE_DIR` (project root) instead of `MHS_DIR`:

```cmake
add_custom_command(
    OUTPUT ${EXAMPLE_PKG}
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_SOURCE_DIR}/.mhscache
    COMMAND ${CMAKE_COMMAND} -E env "MHSDIR=${MHS_DIR}"
        ${MHS_COMPILER} -Pexample-0.1.0 -i${CMAKE_CURRENT_SOURCE_DIR}/src
        Example
        -o ${EXAMPLE_PKG}
    DEPENDS
        ${CMAKE_CURRENT_SOURCE_DIR}/src/Example.hs
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}  # <-- Changed from MHS_DIR
    COMMENT "Building example-0.1.0.pkg"
    VERBATIM
)
```

Key changes:
1. `WORKING_DIRECTORY` changed from `${MHS_DIR}` to `${CMAKE_SOURCE_DIR}`
2. Cache clearing now targets `${CMAKE_SOURCE_DIR}/.mhscache`

This ensures the pkg build uses its own isolated cache and doesn't conflict with MicroHs's development environment.

## What's Been Implemented

### 1. mhs-embed.c Changes
- Renamed `--music-modules` to `--app-modules` (generic naming)
- Renamed internal `add_music_modules()` to `add_app_modules()`
- All pkg-mode functionality works correctly

### 2. MhsEmbed.cmake Changes
- Renamed `MUSIC_MODULES` parameter to `APP_MODULES`

### 3. mhs-init-project.py Changes
- Updated `generate_cmake()` to generate all 4 standalone variants
- Added `.mhscache` clearing before pkg compilation
- Added CMake rules for:
  - Building `base-VERSION.pkg` via mcabal
  - Installing base.pkg locally to `build/mcabal/`
  - Building `{project}-0.1.0.pkg` from project modules
  - Generating embedded headers for all 4 variants
- Added `add_{project}_standalone_variant()` CMake function

### 4. Example Project
- CMakeLists.txt updated with cache clearing fix
- All variants tested and working

## Files Modified

- `/mhs-embed/scripts/mhs-embed.c` - `--app-modules` rename
- `/mhs-embed/MhsEmbed.cmake` - `APP_MODULES` rename
- `/mhs-embed/scripts/mhs-init-project.py` - pkg variant support + cache fix
- `/projects/example/CMakeLists.txt` - cache clearing fix

## Test Commands

```bash
# Build all variants
cmake --build build --target example-all

# Test all variants
./build/example-src -r projects/example/app/Main.hs
./build/example-src-zstd -r projects/example/app/Main.hs
./build/example-pkg -r projects/example/app/Main.hs
./build/example-pkg-zstd -r projects/example/app/Main.hs

# Clear all caches if needed
rm -rf .mhscache thirdparty/MicroHs/.mhscache build/projects/example/*.pkg
```

## Notes on MicroHs Caching

MicroHs maintains a `.mhscache` directory **in the current working directory** containing compiled module representations. This cache is normally beneficial for fast incremental compilation, but it can cause issues when:

1. Source files are modified outside the normal build flow
2. The cache is shared between different build configurations
3. The build runs from a directory with a pre-existing cache

For pkg builds, we:
1. Run from `CMAKE_SOURCE_DIR` (project root) instead of `MHS_DIR` (thirdparty/MicroHs)
2. Clear the cache before each pkg compilation

This ensures the pkg build uses its own isolated cache and doesn't conflict with MicroHs's development environment.
