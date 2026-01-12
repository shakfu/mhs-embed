# mhs-embed

Infrastructure for building self-contained MicroHs applications with embedded Haskell libraries and custom FFI bindings.

## Features

- **Standalone binaries**: Embed all MicroHs libraries into a single executable
- **FFI support**: Call C functions from Haskell in both REPL and standalone modes
- **Multiple build variants**: Choose between source embedding, compressed, or precompiled packages
- **Project generator**: Quickly scaffold new MicroHs projects with FFI boilerplate

## Quick Start

```bash
# Clone with submodules
git clone --recursive https://github.com/yourusername/mhs-embed.git
cd mhs-embed

# Build the example project
cmake -B build
cmake --build build

# Run the example
./build/example -r projects/example/examples/Main.hs
```

## Creating a New Project

Use the init script to generate all boilerplate:

```bash
./mhs-embed/scripts/mhs-init-project.py my_project
```

This creates:
```
projects/my_project/
    CMakeLists.txt           # Build configuration
    my_project_ffi.h         # C FFI header
    my_project_ffi.c         # C FFI implementation
    my_project_ffi_wrappers.c # MicroHs FFI wrappers
    my_project_main.c        # REPL entry point
    my_project_standalone_main.c # Standalone entry point
    lib/
        MyProject.hs         # Haskell module with FFI bindings
    examples/
        Main.hs              # Example program
```

Then add it to `CMakeLists.txt`:
```cmake
add_subdirectory(projects/my_project)
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

## Project Structure

```
mhs-embed/
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

### 4. Bind in Haskell (`lib/MyProject.hs`)

```haskell
foreign import ccall "my_project_ffi.h my_project_do_something"
    c_my_project_do_something :: CInt -> CInt -> IO CInt

doSomething :: Int -> Int -> IO Int
doSomething x y = fromIntegral <$>
    c_my_project_do_something (fromIntegral x) (fromIntegral y)
```

## FFI Stack Layout

MicroHs uses a stack-based calling convention:

```
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

## Build Options

Configure via CMake:

```bash
cmake -B build -DBUILD_EXAMPLE=OFF  # Skip example project
```

## VFS Compile-time Options

When building standalone variants, these defines control behavior:

| Define | Description |
|--------|-------------|
| `VFS_EMBEDDED_HEADER` | Path to embedded files header (required) |
| `VFS_USE_ZSTD` | Enable zstd decompression |
| `VFS_USE_PKG` | Use precompiled .pkg files |
| `VFS_DEBUG` | Enable debug logging |

## Requirements

- CMake 3.16+
- C compiler (GCC, Clang, or MSVC)
- Python 3 (for patching scripts)
- Make (for building MicroHs)

## License

MIT License - see [LICENSE](LICENSE) for details.

## See Also

- [MicroHs](https://github.com/augustss/MicroHs) - The MicroHs compiler
- [mhs-embed/README.md](mhs-embed/README.md) - Detailed embedding library documentation
