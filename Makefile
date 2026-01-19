# Makefile for mhs-embed
# Build, clean, and reset targets for MicroHs embedding infrastructure

.PHONY: all build clean reset reset-hard help
.PHONY: example example-src example-src-zstd example-pkg example-pkg-zstd example-all
.PHONY: repl run test
.PHONY: new-project generate-example regenerate-example

# Default target
all: build

# ============================================
# Build targets
# ============================================

build: ## Build all targets (REPL + standalone)
	@cmake -B build
	@cmake --build build

example: ## Build example REPL binary only
	@cmake -B build
	@cmake --build build --target example

example-src: ## Build example-src standalone binary
	@cmake -B build
	@cmake --build build --target example-src

example-src-zstd: ## Build example-src-zstd standalone binary
	@cmake -B build
	@cmake --build build --target example-src-zstd

example-pkg: ## Build example-pkg standalone binary
	@cmake -B build
	@cmake --build build --target example-pkg

example-pkg-zstd: ## Build example-pkg-zstd standalone binary
	@cmake -B build
	@cmake --build build --target example-pkg-zstd

example-all: build ## Alias for build (all example variants)

# ============================================
# Run targets
# ============================================

repl: example ## Start the example REPL
	@./build/example

run: example-src ## Run the example Main.hs with example-src binary
	@./build/example-src -r projects/example/app/Main.hs

test: build ## Test all example variants
	@echo "=== Testing REPL binary (example) ==="
	@./build/example -r projects/example/app/Main.hs
	@echo ""
	@echo "=== Testing example-src ==="
	@./build/example-src -r projects/example/app/Main.hs
	@echo ""
	@echo "=== Testing example-src-zstd ==="
	@./build/example-src-zstd -r projects/example/app/Main.hs
	@echo ""
	@echo "=== Testing example-pkg ==="
	@./build/example-pkg -r projects/example/app/Main.hs
	@echo ""
	@echo "=== Testing example-pkg-zstd ==="
	@./build/example-pkg-zstd -r projects/example/app/Main.hs
	@echo ""
	@echo "All tests passed!"

# ============================================
# Clean targets
# ============================================

clean: ## Remove build directory
	@rm -rf build
	@echo "Cleaned build directory"

clean-example: ## Remove only example build artifacts
	@rm -rf build/projects/example
	@rm -f build/example build/example-src build/example-src-zstd build/example-pkg build/example-pkg-zstd
	@echo "Cleaned example build artifacts"

clean-cache: ## Remove MicroHs cache
	@rm -rf thirdparty/MicroHs/.mhscache
	@echo "Cleaned MicroHs cache"

# ============================================
# Reset targets
# ============================================

reset: clean ## Full reset: remove build, cache, and generated example
	@rm -f .mhscache
	@rm -f projects/example/src/Example.hs
	@rm -f projects/example/CMakeLists.txt
	@rm -f projects/example/example_ffi.c
	@rm -f projects/example/example_ffi.h
	@rm -f projects/example/example_ffi_wrappers.c
	@rm -f projects/example/example_main.c
	@rm -f projects/example/example_standalone_main.c
	@echo "Reset complete. Run 'make generate-example' then 'make build'."

reset-hard: clean-cache clean ## Full reset including MicroHs cache

regenerate-example: ## Remove and regenerate example project from template
	@rm -rf projects/example
	@rm -rf build/projects/example
	@rm -f build/example build/example-standalone
	@./mhs-embed/scripts/mhs-init-project.py example

# ============================================
# Generate targets
# ============================================

generate-example: ## Generate the example project from template
	@./mhs-embed/scripts/mhs-init-project.py example

# ============================================
# Project generation
# ============================================

new-project: ## Create a new project (usage: make new-project NAME=my_project)
ifndef NAME
	@echo "Usage: make new-project NAME=my_project"
	@echo ""
	@echo "This will create a new project in projects/\$$(NAME)/"
	@exit 1
endif
	@./mhs-embed/scripts/mhs-init-project.py $(NAME)
	@echo ""
	@echo "Add to CMakeLists.txt:"
	@echo "  add_subdirectory(projects/$(NAME))"

# ============================================
# Info targets
# ============================================

info: ## Show build info and binary sizes
	@echo "=== Build Info ==="
	@if [ -f build/example ]; then \
		echo "example (REPL):      $$(ls -lh build/example | awk '{print $$5}')"; \
	else \
		echo "example (REPL):      not built"; \
	fi
	@if [ -f build/example-src ]; then \
		echo "example-src:         $$(ls -lh build/example-src | awk '{print $$5}')"; \
	else \
		echo "example-src:         not built"; \
	fi
	@if [ -f build/example-src-zstd ]; then \
		echo "example-src-zstd:    $$(ls -lh build/example-src-zstd | awk '{print $$5}')"; \
	else \
		echo "example-src-zstd:    not built"; \
	fi
	@if [ -f build/example-pkg ]; then \
		echo "example-pkg:         $$(ls -lh build/example-pkg | awk '{print $$5}')"; \
	else \
		echo "example-pkg:         not built"; \
	fi
	@if [ -f build/example-pkg-zstd ]; then \
		echo "example-pkg-zstd:    $$(ls -lh build/example-pkg-zstd | awk '{print $$5}')"; \
	else \
		echo "example-pkg-zstd:    not built"; \
	fi
	@echo ""
	@echo "=== MicroHs Compiler ==="
	@if [ -f thirdparty/MicroHs/bin/mhs ]; then \
		echo "mhs: $$(thirdparty/MicroHs/bin/mhs --version 2>/dev/null || echo 'installed')"; \
	else \
		echo "mhs: not built (will build on first cmake)"; \
	fi

# ============================================
# Help
# ============================================

help: ## Show this help
	@echo "mhs-embed Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make build                 # Build all variants"
	@echo "  make test                  # Test all 5 variants"
	@echo "  make info                  # Show binary sizes"
	@echo "  make reset                 # Clean build artifacts"
	@echo "  make regenerate-example    # Regenerate example from template"
	@echo "  make new-project NAME=foo  # Create new project"
