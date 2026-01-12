# CMakeLists.txt for mhs-embed
# MicroHs standalone embedding infrastructure
#
# This project provides tools and libraries for creating self-contained
# MicroHs applications with embedded Haskell libraries and custom FFI bindings.

cmake_minimum_required(VERSION 3.16)
project(mhs-embed VERSION 0.1.0 LANGUAGES C CXX)

# Build options
option(BUILD_EXAMPLE "Build the example project" ON)

# Set output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

# ============================================
# MicroHs paths
# ============================================

set(MHS_DIR ${CMAKE_SOURCE_DIR}/thirdparty/MicroHs)
set(MHS_RUNTIME ${MHS_DIR}/src/runtime)
set(MHS_LIB ${MHS_DIR}/lib)
set(ZSTD_DIR ${CMAKE_SOURCE_DIR}/thirdparty/zstd-1.5.7)
set(MHS_EMBED_DIR ${CMAKE_SOURCE_DIR}/mhs-embed)

if(WIN32)
    set(MHS_COMPILER ${MHS_DIR}/bin/mhs.exe)
else()
    set(MHS_COMPILER ${MHS_DIR}/bin/mhs)
endif()

# Build MicroHs compiler if it doesn't exist
if(NOT EXISTS ${MHS_COMPILER})
    message(STATUS "Building MicroHs compiler...")
    if(WIN32)
        execute_process(
            COMMAND nmake -f Makefile.windows
            WORKING_DIRECTORY ${MHS_DIR}
            RESULT_VARIABLE MHS_BUILD_RESULT
        )
    else()
        execute_process(
            COMMAND make
            WORKING_DIRECTORY ${MHS_DIR}
            RESULT_VARIABLE MHS_BUILD_RESULT
        )
    endif()
    if(NOT MHS_BUILD_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to build MicroHs compiler")
    endif()
endif()

# Verify MicroHs compiler exists
if(NOT EXISTS ${MHS_COMPILER})
    message(FATAL_ERROR "MicroHs compiler not found at ${MHS_COMPILER}")
endif()

# Python is needed for patching scripts
find_package(Python3 REQUIRED COMPONENTS Interpreter)

# ============================================
# mhs-embed tool
# ============================================

set(MHS_EMBED_TOOL ${CMAKE_BINARY_DIR}/mhs-embed)
add_custom_command(
    OUTPUT ${MHS_EMBED_TOOL}
    COMMAND ${CMAKE_C_COMPILER} -O2
        -o ${MHS_EMBED_TOOL}
        ${CMAKE_SOURCE_DIR}/mhs-embed/scripts/mhs-embed.c
        ${ZSTD_DIR}/zstd.c
        -I${ZSTD_DIR}
        -lpthread
    DEPENDS ${CMAKE_SOURCE_DIR}/mhs-embed/scripts/mhs-embed.c
    COMMENT "Building mhs-embed tool"
    VERBATIM
)
add_custom_target(mhs-embed-tool DEPENDS ${MHS_EMBED_TOOL})

# ============================================
# Example project
# ============================================

if(BUILD_EXAMPLE)
    add_subdirectory(projects/example)
endif()

# ============================================
# Convenience targets
# ============================================

# Target to build everything
add_custom_target(all-variants)

if(BUILD_EXAMPLE)
    add_dependencies(all-variants example example-standalone)
endif()
