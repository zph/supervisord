.PHONY: help build build-static clean test install release snapshot check-goreleaser version

# Variables
BINARY_NAME=supervisord
PIDPROXY_BINARY=pidproxy
VERSION?=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
LDFLAGS=-ldflags "-s -w -X main.VERSION=$(VERSION) -X main.COMMIT=$(COMMIT)"
BUILD_DIR=dist
GO=go

# Colors for output
CYAN=\033[0;36m
GREEN=\033[0;32m
YELLOW=\033[1;33m
NC=\033[0m # No Color

## help: Display this help message
help:
	@echo "$(CYAN)supervisord - Makefile commands$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make build              # Build supervisord binary"
	@echo "  make test               # Run tests"
	@echo "  make release            # Create a tagged release"
	@echo "  make snapshot           # Create a snapshot build"

## version: Display version information
version:
	@echo "Version: $(VERSION)"
	@echo "Commit:  $(COMMIT)"

## build: Build the supervisord binary for current platform
build:
	@echo "$(GREEN)Building $(BINARY_NAME) $(VERSION)...$(NC)"
	$(GO) generate ./...
	$(GO) build $(LDFLAGS) -tags=release -o $(BUILD_DIR)/$(BINARY_NAME) .
	@echo "$(GREEN)Built: $(BUILD_DIR)/$(BINARY_NAME)$(NC)"

## build-pidproxy: Build the pidproxy binary for current platform
build-pidproxy:
	@echo "$(GREEN)Building $(PIDPROXY_BINARY)...$(NC)"
	$(GO) build -o $(BUILD_DIR)/$(PIDPROXY_BINARY) ./pidproxy
	@echo "$(GREEN)Built: $(BUILD_DIR)/$(PIDPROXY_BINARY)$(NC)"

## build-all: Build both supervisord and pidproxy
build-all: build build-pidproxy

## build-static: Build a static binary for Linux (requires appropriate toolchain)
build-static:
	@echo "$(GREEN)Building static $(BINARY_NAME)...$(NC)"
	CGO_ENABLED=1 $(GO) build $(LDFLAGS) -tags=release -ldflags="-linkmode external -extldflags -static" -o $(BUILD_DIR)/$(BINARY_NAME)-static .
	@echo "$(GREEN)Built: $(BUILD_DIR)/$(BINARY_NAME)-static$(NC)"

## clean: Remove build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	rm -rf $(BUILD_DIR)
	$(GO) clean
	@echo "$(GREEN)Clean complete$(NC)"

## test: Run tests
test:
	@echo "$(GREEN)Running tests...$(NC)"
	$(GO) test -v -race -coverprofile=coverage.out ./...

## test-coverage: Run tests with coverage report
test-coverage: test
	@echo "$(GREEN)Generating coverage report...$(NC)"
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)Coverage report: coverage.html$(NC)"

## install: Install supervisord to GOPATH/bin
install:
	@echo "$(GREEN)Installing $(BINARY_NAME)...$(NC)"
	$(GO) install $(LDFLAGS) -tags=release .

## tidy: Tidy and verify go modules
tidy:
	@echo "$(GREEN)Tidying go modules...$(NC)"
	$(GO) mod tidy
	$(GO) mod verify

## check-goreleaser: Check if goreleaser is installed
check-goreleaser:
	@which goreleaser > /dev/null || (echo "$(YELLOW)goreleaser not found. Install with: brew install goreleaser$(NC)" && exit 1)

## snapshot: Build snapshot release with goreleaser (no git tag required)
snapshot: check-goreleaser clean
	@echo "$(GREEN)Building snapshot release...$(NC)"
	goreleaser release --snapshot --clean --skip=publish

## release: Create a release with goreleaser (requires git tag)
release: check-goreleaser
	@echo "$(GREEN)Creating release $(VERSION)...$(NC)"
	@if [ -z "$(shell git tag --points-at HEAD)" ]; then \
		echo "$(YELLOW)Warning: No git tag found at HEAD. Create a tag first:$(NC)"; \
		echo "  git tag -a v1.0.0 -m 'Release v1.0.0'"; \
		echo "  git push origin v1.0.0"; \
		exit 1; \
	fi
	goreleaser release --clean

## release-dry-run: Test the release process without publishing
release-dry-run: check-goreleaser
	@echo "$(GREEN)Dry-run release...$(NC)"
	goreleaser release --skip=publish --clean

## tag: Create and push a new git tag (usage: make tag VERSION=v1.0.0)
tag:
	@if [ -z "$(VERSION)" ] || [ "$(VERSION)" = "dev" ]; then \
		echo "$(YELLOW)Usage: make tag VERSION=v1.0.0$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Creating tag $(VERSION)...$(NC)"
	git tag -a $(VERSION) -m "Release $(VERSION)"
	git push origin $(VERSION)
	@echo "$(GREEN)Tag $(VERSION) created and pushed$(NC)"

## fmt: Format Go code
fmt:
	@echo "$(GREEN)Formatting code...$(NC)"
	$(GO) fmt ./...

## lint: Run golangci-lint (requires golangci-lint)
lint:
	@which golangci-lint > /dev/null || (echo "$(YELLOW)golangci-lint not found. Install with: brew install golangci-lint$(NC)" && exit 1)
	@echo "$(GREEN)Running linter...$(NC)"
	golangci-lint run

## deps: Download dependencies
deps:
	@echo "$(GREEN)Downloading dependencies...$(NC)"
	$(GO) mod download

## dev: Build and run supervisord in development mode
dev: build
	@echo "$(GREEN)Running $(BINARY_NAME) in dev mode...$(NC)"
	$(BUILD_DIR)/$(BINARY_NAME) -c supervisor.ini
