# MhsEmbed.cmake - CMake module for embedding MicroHs applications
#
# This module provides functions to build self-contained MicroHs applications
# with embedded Haskell libraries and optional custom FFI.
#
# Usage:
#   include(path/to/MhsEmbed.cmake)
#
#   # Build the mhs-embed tool
#   mhs_embed_tool(mhs_embed_target)
#
#   # Generate embedded header from .hs source files
#   mhs_embed_sources(
#     OUTPUT     mhs_embedded.h
#     LIBDIRS    ${MICROHS_DIR}/lib ${PROJECT_SOURCE_DIR}/lib
#     RUNTIME    ${MICROHS_DIR}/src/runtime
#   )
#
#   # Add standalone executable with VFS support
#   mhs_add_standalone_executable(
#     my_app
#     MICROHS_DIR  ${MICROHS_DIR}
#     EMBEDDED_HEADER ${CMAKE_CURRENT_BINARY_DIR}/mhs_embedded.h
#     FFI_WRAPPERS ${PROJECT_SOURCE_DIR}/my_ffi_wrappers.c
#     FFI_SOURCES  ${PROJECT_SOURCE_DIR}/my_ffi.c
#     EXTRA_SOURCES ${PROJECT_SOURCE_DIR}/my_main.c
#     LIBRARIES    my_lib
#   )
#
# Copyright (c) 2025 - MIT License

cmake_minimum_required(VERSION 3.15)

# Get the directory containing this module
get_filename_component(MHS_RUNTIME_DIR "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)

# Path to the VFS source files
set(MHS_VFS_SOURCE "${MHS_RUNTIME_DIR}/vfs.c")
set(MHS_VFS_HEADER "${MHS_RUNTIME_DIR}/vfs.h")
set(MHS_FFI_OVERRIDE_SOURCE "${MHS_RUNTIME_DIR}/mhs_ffi_override.c")

#------------------------------------------------------------------------------
# mhs_find_zstd()
# Find or build zstd library for compression support
#------------------------------------------------------------------------------
function(mhs_find_zstd ZSTD_DIR)
    if(NOT EXISTS "${ZSTD_DIR}/zstd.c")
        message(FATAL_ERROR "Zstd source not found at ${ZSTD_DIR}")
    endif()

    # Build zstd as object files
    add_library(mhs_zstd STATIC
        ${ZSTD_DIR}/zstd.c
    )
    target_include_directories(mhs_zstd PUBLIC ${ZSTD_DIR})

    # Export variables to parent scope
    set(MHS_ZSTD_LIBRARY mhs_zstd PARENT_SCOPE)
    set(MHS_ZSTD_INCLUDE_DIR ${ZSTD_DIR} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# mhs_embed_tool()
# Build the mhs-embed tool for generating embedded headers
#------------------------------------------------------------------------------
function(mhs_embed_tool TARGET_NAME)
    cmake_parse_arguments(ARG "" "EMBED_SOURCE;ZSTD_DIR" "" ${ARGN})

    # Find mhs-embed.c source
    if(ARG_EMBED_SOURCE)
        set(EMBED_SOURCE ${ARG_EMBED_SOURCE})
    else()
        # Try common locations
        set(EMBED_SOURCE "${CMAKE_SOURCE_DIR}/mhs-embed/scripts/mhs-embed.c")
        if(NOT EXISTS "${EMBED_SOURCE}")
            message(FATAL_ERROR "mhs-embed.c not found. Specify with EMBED_SOURCE.")
        endif()
    endif()

    # Find zstd
    if(ARG_ZSTD_DIR)
        set(ZSTD_DIR ${ARG_ZSTD_DIR})
    else()
        set(ZSTD_DIR "${CMAKE_SOURCE_DIR}/thirdparty/zstd-1.5.7")
    endif()

    if(NOT EXISTS "${ZSTD_DIR}/zstd.c")
        message(FATAL_ERROR "Zstd not found at ${ZSTD_DIR}. Specify with ZSTD_DIR.")
    endif()

    add_executable(${TARGET_NAME}
        ${EMBED_SOURCE}
        ${ZSTD_DIR}/zstd.c
    )
    target_include_directories(${TARGET_NAME} PRIVATE ${ZSTD_DIR})
    target_compile_definitions(${TARGET_NAME} PRIVATE ZSTD_STATIC_LINKING_ONLY)
    find_package(Threads REQUIRED)
    target_link_libraries(${TARGET_NAME} PRIVATE Threads::Threads)
endfunction()

#------------------------------------------------------------------------------
# mhs_embed_sources()
# Generate an embedded header file from Haskell source directories
#------------------------------------------------------------------------------
function(mhs_embed_sources)
    cmake_parse_arguments(ARG
        "NO_COMPRESS;PKG_MODE"
        "OUTPUT;EMBED_TOOL;RUNTIME"
        "LIBDIRS;LIBS;HEADERS;PKGS;TXT_DIRS;APP_MODULES"
        ${ARGN}
    )

    if(NOT ARG_OUTPUT)
        message(FATAL_ERROR "mhs_embed_sources: OUTPUT is required")
    endif()

    if(NOT ARG_EMBED_TOOL)
        set(ARG_EMBED_TOOL mhs_embed)
    endif()

    # Build command arguments
    set(EMBED_ARGS ${ARG_OUTPUT})

    # Add library directories
    foreach(LIBDIR ${ARG_LIBDIRS})
        list(APPEND EMBED_ARGS ${LIBDIR})
    endforeach()

    # Add runtime directory
    if(ARG_RUNTIME)
        list(APPEND EMBED_ARGS --runtime ${ARG_RUNTIME})
    endif()

    # Add individual library files
    foreach(LIB ${ARG_LIBS})
        list(APPEND EMBED_ARGS --lib ${LIB})
    endforeach()

    # Add individual header files
    foreach(HDR ${ARG_HEADERS})
        list(APPEND EMBED_ARGS --header ${HDR})
    endforeach()

    # Package mode options
    if(ARG_PKG_MODE)
        list(APPEND EMBED_ARGS --pkg-mode)
    endif()

    foreach(PKG ${ARG_PKGS})
        list(APPEND EMBED_ARGS --pkg ${PKG})
    endforeach()

    foreach(TXT_DIR ${ARG_TXT_DIRS})
        list(APPEND EMBED_ARGS --txt-dir ${TXT_DIR})
    endforeach()

    foreach(APP_MOD ${ARG_APP_MODULES})
        list(APPEND EMBED_ARGS --app-modules ${APP_MOD})
    endforeach()

    # Compression
    if(ARG_NO_COMPRESS)
        list(APPEND EMBED_ARGS --no-compress)
    endif()

    # Create custom command
    add_custom_command(
        OUTPUT ${ARG_OUTPUT}
        COMMAND ${ARG_EMBED_TOOL} ${EMBED_ARGS}
        DEPENDS ${ARG_EMBED_TOOL}
        COMMENT "Generating embedded header ${ARG_OUTPUT}"
        VERBATIM
    )

    # Create custom target
    get_filename_component(OUTPUT_NAME ${ARG_OUTPUT} NAME_WE)
    add_custom_target(${OUTPUT_NAME}_header DEPENDS ${ARG_OUTPUT})
endfunction()

#------------------------------------------------------------------------------
# mhs_patch_sources()
# Patch MicroHs source files for custom FFI and VFS support
#------------------------------------------------------------------------------
function(mhs_patch_sources)
    cmake_parse_arguments(ARG "" "MICROHS_DIR;OUTPUT_DIR" "" ${ARGN})

    if(NOT ARG_MICROHS_DIR)
        message(FATAL_ERROR "mhs_patch_sources: MICROHS_DIR is required")
    endif()

    if(NOT ARG_OUTPUT_DIR)
        set(ARG_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
    endif()

    set(SCRIPTS_DIR "${CMAKE_SOURCE_DIR}/mhs-embed/scripts")
    set(MHS_C "${ARG_MICROHS_DIR}/generated/mhs.c")
    set(EVAL_C "${ARG_MICROHS_DIR}/src/runtime/eval.c")

    # Patch mhs.c to remove xffi_table
    set(MHS_PATCHED "${ARG_OUTPUT_DIR}/mhs_patched.c")
    add_custom_command(
        OUTPUT ${MHS_PATCHED}
        COMMAND ${CMAKE_COMMAND} -E env python3 ${SCRIPTS_DIR}/mhs-patch-xffi.py ${MHS_C} ${MHS_PATCHED}
        DEPENDS ${MHS_C} ${SCRIPTS_DIR}/mhs-patch-xffi.py
        COMMENT "Patching mhs.c for custom FFI"
        VERBATIM
    )

    # Patch eval.c for VFS support
    set(EVAL_PATCHED "${ARG_OUTPUT_DIR}/eval_vfs.c")
    add_custom_command(
        OUTPUT ${EVAL_PATCHED}
        COMMAND ${CMAKE_COMMAND} -E env python3 ${SCRIPTS_DIR}/mhs-patch-eval.py ${EVAL_C} ${EVAL_PATCHED}
        DEPENDS ${EVAL_C} ${SCRIPTS_DIR}/mhs-patch-eval.py
        COMMENT "Patching eval.c for VFS support"
        VERBATIM
    )

    # Export paths to parent scope
    set(MHS_PATCHED_SOURCE ${MHS_PATCHED} PARENT_SCOPE)
    set(EVAL_VFS_SOURCE ${EVAL_PATCHED} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------------
# mhs_add_repl_executable()
# Add a MicroHs REPL executable (non-standalone, requires MHSDIR)
#------------------------------------------------------------------------------
function(mhs_add_repl_executable TARGET_NAME)
    cmake_parse_arguments(ARG
        ""
        "MICROHS_DIR"
        "FFI_WRAPPERS;FFI_SOURCES;EXTRA_SOURCES;LIBRARIES;INCLUDE_DIRS"
        ${ARGN}
    )

    if(NOT ARG_MICROHS_DIR)
        message(FATAL_ERROR "mhs_add_repl_executable: MICROHS_DIR is required")
    endif()

    # Patch mhs.c
    mhs_patch_sources(MICROHS_DIR ${ARG_MICROHS_DIR})

    # Core sources
    set(SOURCES
        ${MHS_PATCHED_SOURCE}
        ${ARG_MICROHS_DIR}/src/runtime/eval.c
    )

    # Add FFI wrappers and sources
    list(APPEND SOURCES ${ARG_FFI_WRAPPERS})
    list(APPEND SOURCES ${ARG_FFI_SOURCES})
    list(APPEND SOURCES ${ARG_EXTRA_SOURCES})

    add_executable(${TARGET_NAME} ${SOURCES})

    target_include_directories(${TARGET_NAME} PRIVATE
        ${ARG_MICROHS_DIR}/src/runtime
        ${ARG_INCLUDE_DIRS}
    )

    target_link_libraries(${TARGET_NAME} PRIVATE ${ARG_LIBRARIES})
endfunction()

#------------------------------------------------------------------------------
# mhs_add_standalone_executable()
# Add a standalone MicroHs executable with embedded libraries via VFS
#------------------------------------------------------------------------------
function(mhs_add_standalone_executable TARGET_NAME)
    cmake_parse_arguments(ARG
        "USE_ZSTD;USE_PKG"
        "MICROHS_DIR;EMBEDDED_HEADER;ZSTD_DIR"
        "FFI_WRAPPERS;FFI_SOURCES;EXTRA_SOURCES;LIBRARIES;INCLUDE_DIRS"
        ${ARGN}
    )

    if(NOT ARG_MICROHS_DIR)
        message(FATAL_ERROR "mhs_add_standalone_executable: MICROHS_DIR is required")
    endif()

    if(NOT ARG_EMBEDDED_HEADER)
        message(FATAL_ERROR "mhs_add_standalone_executable: EMBEDDED_HEADER is required")
    endif()

    # Patch sources
    mhs_patch_sources(MICROHS_DIR ${ARG_MICROHS_DIR})

    # Core sources
    set(SOURCES
        ${MHS_PATCHED_SOURCE}
        ${EVAL_VFS_SOURCE}
        ${MHS_VFS_SOURCE}
        ${MHS_FFI_OVERRIDE_SOURCE}
    )

    # Add FFI wrappers and sources
    list(APPEND SOURCES ${ARG_FFI_WRAPPERS})
    list(APPEND SOURCES ${ARG_FFI_SOURCES})
    list(APPEND SOURCES ${ARG_EXTRA_SOURCES})

    add_executable(${TARGET_NAME} ${SOURCES})

    # Get directory containing the embedded header
    get_filename_component(EMBEDDED_HEADER_DIR ${ARG_EMBEDDED_HEADER} DIRECTORY)
    get_filename_component(EMBEDDED_HEADER_NAME ${ARG_EMBEDDED_HEADER} NAME)

    target_include_directories(${TARGET_NAME} PRIVATE
        ${ARG_MICROHS_DIR}/src/runtime
        ${MHS_RUNTIME_DIR}
        ${EMBEDDED_HEADER_DIR}
        ${ARG_INCLUDE_DIRS}
    )

    target_compile_definitions(${TARGET_NAME} PRIVATE
        VFS_EMBEDDED_HEADER=${EMBEDDED_HEADER_NAME}
    )

    # Zstd support
    if(ARG_USE_ZSTD)
        if(NOT ARG_ZSTD_DIR)
            set(ARG_ZSTD_DIR "${CMAKE_SOURCE_DIR}/thirdparty/zstd-1.5.7")
        endif()

        target_compile_definitions(${TARGET_NAME} PRIVATE VFS_USE_ZSTD)
        target_include_directories(${TARGET_NAME} PRIVATE ${ARG_ZSTD_DIR})

        # Build zstd if not already built
        if(NOT TARGET mhs_zstd_${TARGET_NAME})
            add_library(mhs_zstd_${TARGET_NAME} STATIC ${ARG_ZSTD_DIR}/zstd.c)
            target_include_directories(mhs_zstd_${TARGET_NAME} PUBLIC ${ARG_ZSTD_DIR})
        endif()
        target_link_libraries(${TARGET_NAME} PRIVATE mhs_zstd_${TARGET_NAME})
    endif()

    # Package mode
    if(ARG_USE_PKG)
        target_compile_definitions(${TARGET_NAME} PRIVATE VFS_USE_PKG)
    endif()

    target_link_libraries(${TARGET_NAME} PRIVATE ${ARG_LIBRARIES})
endfunction()

