# mhs-embed

Infrastructure for building self-contained [MicroHs](https://github.com/augustss/MicroHs) applications with embedded Haskell libraries and custom FFI bindings.

## Features

- **Standalone binaries**: Embed all MicroHs libraries into a single executable
- **FFI support**: Call C functions from Haskell in both REPL and standalone modes
- **Multiple build variants**: Choose between source embedding, compressed, or precompiled packages
- **Project generator**: Quickly scaffold new MicroHs projects with FFI boilerplate

## Quick Start

```bash
# Clone with submodules
git clone --recursive https://github.com/anthropics/mhs-embed.git
cd mhs-embed

# Generate and build the example project
make generate-example
make build

# Run the example
make run
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make build` | Build all targets (REPL + standalone) |
| `make run` | Run example with standalone binary |
| `make test` | Test both REPL and standalone binaries |
| `make reset` | Remove build artifacts and generated files (preserves `app/Main.hs`) |
| `make generate-example` | Generate example project (skips existing `app/Main.hs`) |
| `make regenerate-example` | Full wipe and fresh generation |
| `make new-project NAME=foo` | Create a new project |
| `make clean` | Remove build directory |
| `make help` | Show all targets |

## Creating a New Project

Use the init script to generate all boilerplate:

```bash
./mhs-embed/scripts/mhs-init-project.py my_project
```

This creates:

```text
projects/my_project/
    CMakeLists.txt           # Build configuration
    my_project_ffi.h         # C FFI header
    my_project_ffi.c         # C FFI implementation
    my_project_ffi_wrappers.c # MicroHs FFI wrappers
    my_project_main.c        # REPL entry point
    my_project_standalone_main.c # Standalone entry point
    src/
        MyProject.hs         # Haskell module with FFI bindings
    app/
        Main.hs              # Application entry point
```

Then add it to `CMakeLists.txt`:

```cmake
add_subdirectory(projects/my_project)
```

### Init Script Options

```bash
./mhs-embed/scripts/mhs-init-project.py my_project              # Create new project
./mhs-embed/scripts/mhs-init-project.py my_project --force      # Overwrite app/Main.hs if exists
./mhs-embed/scripts/mhs-init-project.py my_project --no-cmake   # Skip CMakeLists.txt
./mhs-embed/scripts/mhs-init-project.py my_project -o path/     # Custom output directory
```

## Build Variants

### REPL Mode (non-standalone)

Smaller binary that requires `MHSDIR` environment variable or auto-detection:

```bash
./build/my_project              # Start REPL
./build/my_project -r file.hs   # Run a file
```

### Standalone Mode

Self-contained binary with all MicroHs libraries embedded:

```bash
./build/my_project-standalone              # Start REPL (no MHSDIR needed)
./build/my_project-standalone -r file.hs   # Run a file
./build/my_project-standalone -oMyProg file.hs  # Compile to executable
```

### Standalone Variants

| Variant | Flags | Startup | Size | Description |
|---------|-------|---------|------|-------------|
| `-src` | (default) | ~19s | Large | Embedded .hs source files |
| `-src-zstd` | `VFS_USE_ZSTD` | ~19s | Medium | Compressed source files |
| `-pkg` | `VFS_USE_PKG` | ~0.5s | Large | Precompiled .pkg files |
| `-pkg-zstd` | `VFS_USE_PKG VFS_USE_ZSTD` | ~0.5s | Small | Compressed packages |

## Project Structure

```text
mhs-embed/
    Makefile                # Build, test, reset targets
    CMakeLists.txt          # Top-level build configuration
    mhs-embed/              # Core embedding library (self-contained)
        vfs.c / vfs.h       # Virtual filesystem for embedded files
        mhs_ffi_override.c  # Routes file operations through VFS
        MhsEmbed.cmake      # CMake helper functions
        scripts/
            mhs-init-project.py # Project generator
            mhs-embed.c         # Embedding tool (generates C headers)
            mhs-patch-xffi.py   # Patches mhs.c for custom FFI
            mhs-patch-eval.py   # Patches eval.c for VFS support
    thirdparty/
        MicroHs/            # MicroHs compiler and runtime
        zstd-1.5.7/         # Zstd compression library
    projects/
        example/            # Example project
            src/            # Haskell library modules
            app/            # Application entry points
```

## Adding FFI Functions

### 1. Declare in C header (`my_project_ffi.h`)

```c
int my_project_do_something(int x, int y);
```

### 2. Implement in C (`my_project_ffi.c`)

```c
int my_project_do_something(int x, int y) {
    return x + y;
}
```

### 3. Add wrapper (`my_project_ffi_wrappers.c`)

```c
// Wrapper converts MicroHs stack to C call
from_t mhs_my_project_do_something(int s) {
    int x = mhs_to_Int(s, 0);  // First argument
    int y = mhs_to_Int(s, 1);  // Second argument
    int result = my_project_do_something(x, y);
    return mhs_from_Int(s, 2, result);  // 2 = arity = result slot
}

// Add to FFI table:
{ "my_project_do_something", 2, mhs_my_project_do_something },
```

### 4. Bind in Haskell (`src/MyProject.hs`)

```haskell
foreign import ccall "my_project_ffi.h my_project_do_something"
    c_my_project_do_something :: CInt -> CInt -> IO CInt

doSomething :: Int -> Int -> IO Int
doSomething x y = fromIntegral <$>
    c_my_project_do_something (fromIntegral x) (fromIntegral y)
```

## FFI Stack Layout

MicroHs uses a stack-based calling convention:

```text
Function: f(a, b, c) -> result

Stack before: [a, b, c]
              ^0 ^1 ^2

Stack after:  [result]
              ^3 (arity = result slot)
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

## VFS Compile-time Options

When building standalone variants, these defines control behavior:

| Define | Description |
|--------|-------------|
| `VFS_EMBEDDED_HEADER` | Path to embedded files header (required) |
| `VFS_USE_ZSTD` | Enable zstd decompression |
| `VFS_USE_PKG` | Use precompiled .pkg files |
| `VFS_DEBUG` | Enable debug logging |

## Architecture

```text
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
                    | (mhs-embed/)  |
                    +---------------+
                            |
                    +-------v-------+
                    |  Embedded     |
                    |  Files        |
                    +---------------+
```

## Requirements

- CMake 3.16+
- C compiler (GCC, Clang, or MSVC)
- Python 3 (for patching scripts)
- Make (for building MicroHs)

## License

MIT License - see [LICENSE](LICENSE) for details.

## See Also

- [MicroHs](https://github.com/augustss/MicroHs) - The MicroHs compiler
