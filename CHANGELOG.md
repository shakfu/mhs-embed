# Changelog

All notable changes to mhs-embed will be documented in this file.

## [Unreleased]

## [0.1.0]

### Added

- Initial project structure extracted from midi-langs
- Project generator script (`mhs-embed/scripts/mhs-init-project.py`)
- Makefile with build, test, reset, and generation targets
- Example project in `projects/example/`
- VFS (Virtual Filesystem) for embedding files into standalone binaries
- FFI wrapper infrastructure for C/Haskell interop
- CMake build system with helper functions
- Support for multiple standalone variants (source, compressed, precompiled)

### Project Structure

- `mhs-embed/` - Core embedding library (self-contained)
  - `vfs.c`, `vfs.h` - Virtual filesystem implementation
  - `mhs_ffi_override.c` - Routes MicroHs file operations through VFS
  - `MhsEmbed.cmake` - CMake helper functions
  - `scripts/` - Build and generation tools
- `projects/` - User projects directory
- `thirdparty/` - MicroHs and zstd dependencies

### Init Script Features

- Generates complete project boilerplate (FFI files, CMake, Haskell modules)
- `--force` flag to overwrite existing `app/Main.hs`
- `--no-cmake` flag to skip CMakeLists.txt generation
- `-o` flag for custom output directory
- Preserves user code in `app/Main.hs` by default during regeneration

### Makefile Targets

- `make build` - Build all targets (REPL + standalone)
- `make run` - Run example with standalone binary
- `make test` - Test both REPL and standalone binaries
- `make reset` - Remove generated files (preserves `app/Main.hs`)
- `make regenerate-example` - Full wipe and fresh generation
- `make generate-example` - Generate example (skips existing `app/Main.hs`)
- `make new-project NAME=foo` - Create a new project
- `make clean` - Remove build directory

### Fixed

- Module discovery for Haskell-style `src/` directory structure
- Added `-i/mhs-embedded/src` include path for standalone binaries
- Path calculation in init script after moving to `mhs-embed/scripts/`
