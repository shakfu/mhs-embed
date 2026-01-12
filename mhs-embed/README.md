# MicroHs Embedding Library

This library provides infrastructure for building self-contained MicroHs applications with embedded Haskell libraries and custom FFI bindings.

## Quick Start

The fastest way to create a new MicroHs project:

```bash
./mhs-embed/scripts/mhs-init-project.py my_project
```

This generates all boilerplate files in `projects/my_project/`.

## Components

### Core Files

| File | Description |
|------|-------------|
| `vfs.c` / `vfs.h` | Virtual Filesystem - serves embedded files from memory |
| `mhs_ffi_override.c` | Routes MicroHs file operations through VFS |
| `MhsEmbed.cmake` | CMake module for build integration |

### Tools

| Script | Description |
|--------|-------------|
| `mhs-embed/scripts/mhs-init-project.py` | Generate new project from templates |
| `mhs-embed/scripts/mhs-embed.c` | Embed files into C headers |
| `mhs-embed/scripts/mhs-patch-xffi.py` | Patch mhs.c for custom FFI table |
| `mhs-embed/scripts/mhs-patch-eval.py` | Patch eval.c for VFS support |

## Build Variants

### REPL Mode (non-standalone)

Requires `MHSDIR` environment variable or auto-detection.
Smaller binary, uses external MicroHs library files.

### Standalone Variants

Self-contained binaries with all files embedded:

| Variant | Flags | Startup | Size | Description |
|---------|-------|---------|------|-------------|
| `-src` | (default) | ~19s | Large | Embedded .hs source files |
| `-src-zstd` | `VFS_USE_ZSTD` | ~19s | Medium | Compressed source files |
| `-pkg` | `VFS_USE_PKG` | ~0.5s | Large | Precompiled .pkg files |
| `-pkg-zstd` | `VFS_USE_PKG VFS_USE_ZSTD` | ~0.5s | Small | Compressed packages |

## Usage

### 1. Initialize Project

```bash
./mhs-embed/scripts/mhs-init-project.py my_audio
```

Generated files:
```
projects/my_audio/
    CMakeLists.txt           # Build configuration
    my_audio_ffi.h           # C FFI header
    my_audio_ffi.c           # C FFI implementation
    my_audio_ffi_wrappers.c  # MicroHs FFI wrappers
    my_audio_main.c          # REPL entry point
    my_audio_standalone_main.c # Standalone entry point
    lib/
        MyAudio.hs           # Haskell module with FFI bindings
    examples/
        Main.hs              # Example program
```

### 2. Customize Your FFI

Edit `my_audio_ffi.h` and `my_audio_ffi.c` with your C API:

```c
// my_audio_ffi.h
int my_audio_play_note(int pitch, int velocity, int duration);
```

```c
// my_audio_ffi.c
int my_audio_play_note(int pitch, int velocity, int duration) {
    // Your implementation
    return 0;
}
```

### 3. Add FFI Wrapper

Add wrapper in `my_audio_ffi_wrappers.c`:

```c
from_t mhs_my_audio_play_note(int s) {
    return mhs_from_Int(s, 3, my_audio_play_note(
        mhs_to_Int(s, 0),  // pitch
        mhs_to_Int(s, 1),  // velocity
        mhs_to_Int(s, 2)   // duration
    ));
}

// Add to table:
{ "my_audio_play_note", 3, mhs_my_audio_play_note },
```

### 4. Add Haskell Binding

In `lib/MyAudio.hs`:

```haskell
foreign import ccall "my_audio_ffi.h my_audio_play_note"
    c_my_audio_play_note :: CInt -> CInt -> CInt -> IO CInt

playNote :: Int -> Int -> Int -> IO Bool
playNote pitch vel dur = do
    result <- c_my_audio_play_note
        (fromIntegral pitch)
        (fromIntegral vel)
        (fromIntegral dur)
    return (result == 0)
```

### 5. Build

```bash
# Add to main CMakeLists.txt:
# add_subdirectory(projects/my_audio)

cmake -B build
cmake --build build
```

### 6. Run

```bash
# REPL mode
./build/my_audio

# Run a script
./build/my_audio -r examples/Main.hs

# Compile to executable
./build/my_audio -oMyProg examples/Main.hs
```

## CMake Integration

Include the CMake module for helper functions:

```cmake
include(${CMAKE_SOURCE_DIR}/mhs-embed/MhsEmbed.cmake)

# Build mhs-embed tool
mhs_embed_tool(mhs_embed)

# Generate embedded header
mhs_embed_sources(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/mhs_embedded.h
    LIBDIRS ${MHS_LIB} ${MY_LIB}
    RUNTIME ${MHS_RUNTIME}
    NO_COMPRESS
)

# Add standalone executable
mhs_add_standalone_executable(my_app
    MICROHS_DIR ${MHS_DIR}
    EMBEDDED_HEADER ${CMAKE_CURRENT_BINARY_DIR}/mhs_embedded.h
    FFI_WRAPPERS my_ffi_wrappers.c
    FFI_SOURCES my_ffi.c
    EXTRA_SOURCES my_main.c
)
```

## VFS Configuration

When compiling `vfs.c`, set `VFS_EMBEDDED_HEADER` to your generated header:

```cmake
target_compile_definitions(my_app PRIVATE
    VFS_EMBEDDED_HEADER=mhs_embedded.h
)
```

### Compile-time Options

| Define | Description |
|--------|-------------|
| `VFS_EMBEDDED_HEADER` | Path to embedded files header (required) |
| `VFS_USE_ZSTD` | Enable zstd decompression |
| `VFS_USE_PKG` | Use precompiled .pkg files |
| `VFS_DEBUG` | Enable debug logging |

## FFI Wrapper Reference

### Stack Layout

MicroHs uses a stack-based calling convention:

```
Function: f(a, b, c) -> result

Stack before: [a, b, c]
              ^0 ^1 ^2

Stack after:  [result]
              ^3 (arity)
```

### Type Conversions

| Haskell Type | C Type | To C | From C |
|--------------|--------|------|--------|
| `Int` | `int` | `mhs_to_Int(s, slot)` | `mhs_from_Int(s, slot, val)` |
| `Ptr a` | `void*` | `mhs_to_Ptr(s, slot)` | `mhs_from_Ptr(s, slot, val)` |
| `()` | void | N/A | `mhs_from_Unit(s, slot)` |

### Example Wrappers

```c
// 0-arity: () -> Int
from_t mhs_get_value(int s) {
    return mhs_from_Int(s, 0, get_value());
}

// 1-arity: Int -> ()
from_t mhs_set_value(int s) {
    set_value(mhs_to_Int(s, 0));
    return mhs_from_Unit(s, 1);
}

// 2-arity: Int -> Int -> Int
from_t mhs_add(int s) {
    int a = mhs_to_Int(s, 0);
    int b = mhs_to_Int(s, 1);
    return mhs_from_Int(s, 2, a + b);
}

// 3-arity: Ptr -> Int -> Int -> Int
from_t mhs_send(int s) {
    const char* str = mhs_to_Ptr(s, 0);
    int x = mhs_to_Int(s, 1);
    int y = mhs_to_Int(s, 2);
    return mhs_from_Int(s, 3, send(str, x, y));
}
```

## Architecture

```
                    +------------------+
                    |   Your Project   |
                    +------------------+
                            |
        +-------------------+-------------------+
        |                   |                   |
+-------v-------+   +-------v-------+   +-------v-------+
|  FFI Header   |   | FFI Wrappers  |   |   Haskell    |
| (C interface) |   | (stack<->C)   |   |   Modules    |
+---------------+   +---------------+   +---------------+
        |                   |                   |
        +-------------------+-------------------+
                            |
                    +-------v-------+
                    |  MicroHs      |
                    |  Runtime      |
                    +---------------+
                            |
                    +-------v-------+
                    |  VFS Layer    |
                    | (lib/mhs-     |
                    |  embed/)      |
                    +---------------+
                            |
                    +-------v-------+
                    |  Embedded     |
                    |  Files        |
                    +---------------+
```

## See Also

- `projects/example/` - Example project with FFI
- `thirdparty/MicroHs/` - MicroHs compiler and runtime
- `mhs-embed/scripts/mhs-embed.c` - Embedding tool source
- `mhs-embed/scripts/mhs-init-project.py` - Project generator script
