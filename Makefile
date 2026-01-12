# Makefile for mhs-embed
# Build, clean, and reset targets for MicroHs embedding infrastructure

.PHONY: all build clean reset help
.PHONY: example example-standalone example-all
.PHONY: repl run test
.PHONY: new-project generate-example

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

example-standalone: ## Build example standalone binary only
	@cmake -B build
	@cmake --build build --target example-standalone

example-all: build ## Alias for build (all example variants)

# ============================================
# Run targets
# ============================================

repl: example ## Start the example REPL
	@./build/example

run: example-standalone ## Run the example Main.hs with standalone binary
	@./build/example-standalone -r projects/example/examples/Main.hs

test: example-standalone ## Test both REPL and standalone binaries
	@echo "=== Testing REPL binary ==="
	@./build/example -r projects/example/examples/Main.hs
	@echo ""
	@echo "=== Testing standalone binary ==="
	@./build/example-standalone -r projects/example/examples/Main.hs
	@echo ""
	@echo "=== Testing standalone without MHSDIR ==="
	@unset MHSDIR && ./build/example-standalone -r projects/example/examples/Main.hs
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
	@rm -f build/example build/example-standalone
	@echo "Cleaned example build artifacts"

clean-cache: ## Remove MicroHs cache
	@rm -rf thirdparty/MicroHs/.mhscache
	@echo "Cleaned MicroHs cache"

# ============================================
# Reset targets
# ============================================

reset: ## Full reset: remove build and example project
	@rm -rf build
	@rm -rf projects/example
	@echo "Reset complete. Run 'make generate-example' then 'make build'."

reset-example: ## Remove example project only (keeps build dir)
	@rm -rf projects/example
	@rm -rf build/projects/example
	@rm -f build/example build/example-standalone
	@echo "Example removed. Run 'make generate-example' then 'make build'."

reset-hard: clean-cache reset ## Full reset including MicroHs cache

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
	@if [ -f build/example-standalone ]; then \
		echo "example-standalone:  $$(ls -lh build/example-standalone | awk '{print $$5}')"; \
	else \
		echo "example-standalone:  not built"; \
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
	@echo "  make build                    # Build all variants"
	@echo "  make test                     # Run tests"
	@echo "  make reset && make generate-example  # Reset and regenerate"
	@echo "  make new-project NAME=foo     # Create new project"
