# TODO

## Build Variants

- [ ] Add support for building .pkg-based standalone binaries
  - Precompile Haskell sources to .pkg files using `mhs -C`
  - Embed .pkg files instead of .hs sources for faster startup (~0.5s vs ~19s)
  - Add `-pkg` and `-pkg-zstd` CMake targets
  - Update init script to generate CMake rules for pkg variants

## Testing

- [ ] Add automated CI tests
- [ ] Test Windows build path
