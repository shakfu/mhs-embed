# TODO

## Build Variants

- [x] Add support for building .pkg-based standalone binaries
  - [x] Precompile Haskell sources to .pkg files using `mhs -P`
  - [x] Embed .pkg files instead of .hs sources
  - [x] Add `-pkg` and `-pkg-zstd` CMake targets
  - [x] Update init script to generate CMake rules for pkg variants
  - [x] Fixed: pkg variants now work (added .mhscache clearing to ensure fresh builds)
  - See PKG_IMPL.md for implementation details

## Testing

- [ ] Add automated CI tests
- [ ] Test Windows build path
