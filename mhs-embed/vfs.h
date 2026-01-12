/* vfs.h - Virtual Filesystem for MicroHs embedded libraries
 *
 * This is part of the MicroHs runtime embedding library.
 * Use this to build self-contained MicroHs applications with
 * embedded Haskell source files or precompiled packages.
 *
 * Copyright (c) 2025 - MIT License
 */

#ifndef MHS_VFS_H
#define MHS_VFS_H

#include <stdio.h>
#include <stddef.h>
#include <dirent.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Virtual root path used for embedded files.
 * All embedded files are accessible under this prefix.
 */
#define VFS_VIRTUAL_ROOT "/mhs-embedded"

/* Initialize VFS.
 * Must be called before using other VFS functions.
 * Returns 0 on success, -1 on failure.
 */
int vfs_init(void);

/* Shutdown VFS and free resources.
 * Should be called on application exit.
 */
void vfs_shutdown(void);

/* Get the virtual root path (for setting MHSDIR).
 * Returns VFS_VIRTUAL_ROOT ("/mhs-embedded").
 */
const char* vfs_get_temp_dir(void);

/* Open a file - checks embedded files first, then falls back to filesystem.
 * For paths starting with VFS_VIRTUAL_ROOT, looks up in embedded files
 * and uses fmemopen() to return a FILE* from memory.
 */
FILE* vfs_fopen(const char* path, const char* mode);

/* Directory operations for VFS
 * These intercept opendir/readdir/closedir for virtual paths
 */

/* Open a directory - checks VFS first, then falls back to filesystem */
DIR* vfs_opendir(const char* path);

/* Read next entry from directory */
struct dirent* vfs_readdir(DIR* dirp);

/* Close directory */
int vfs_closedir(DIR* dirp);

/* Get total number of embedded files */
int vfs_file_count(void);

/* Get total size of embedded content (uncompressed) */
size_t vfs_total_size(void);

/* Get size of embedded data in binary (compressed if applicable) */
size_t vfs_embedded_size(void);

/* Print VFS statistics */
void vfs_print_stats(void);

/* List all embedded files (for debugging) */
void vfs_list_files(void);

/* Extract all embedded files to a temp directory.
 * Returns the path to the temp directory, or NULL on failure.
 * Use this when compiling to executable (cc needs real files).
 * Caller must free the returned path with vfs_cleanup_temp().
 */
char* vfs_extract_to_temp(void);

/* Clean up extracted temp directory */
void vfs_cleanup_temp(char* temp_dir);

/* Clear decompression cache (for zstd modes only) */
#ifdef VFS_USE_ZSTD
void vfs_clear_cache(void);
#endif

#ifdef __cplusplus
}
#endif

#endif /* MHS_VFS_H */
