.PHONY: all setup setup-tools setup-plugins serve build publish lint format check clean
.PHONY: mcp-start mcp-stop install-rojo-plugin install-mcp-plugin setup-docs verify setup-hooks

# Tool versions
ROJO_VERSION     := 7.6.1
LUNE_VERSION     := 0.10.4
SELENE_VERSION   := 0.29.0
STYLUA_VERSION   := 2.3.1
TARMAC_VERSION   := 0.8.2
RBXCLOUD_VERSION := 0.17.0
WALLY_VERSION    := 0.3.2

# MCP Server (fork with Linux support and --http-only mode)
MCP_SERVER_REPO    := dnouri/studio-rust-mcp-server
MCP_SERVER_VERSION := 0.2.22

# Plugin installation directory (auto-detected or override in .env)
-include .env
ROBLOX_PLUGINS_DIR ?= $(shell ./scripts/detect-plugins-dir.sh 2>/dev/null)

# OS detection
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    # OS_SUFFIX := linux
    ROJO_OS_SUFFIX := linux-x86_64
    LUNE_OS_SUFFIX := linux-x86_64
    SELENE_OS_SUFFIX := linux
    STYLUA_OS_SUFFIX := linux-x86_64
    TARMAC_OS_SUFFIX := linux
    RBXCLOUD_OS_SUFFIX := linux
    WALLY_OS_SUFFIX := linux
    MCP_OS_SUFFIX := linux
endif
ifeq ($(UNAME_S),Darwin)
    # OS_SUFFIX := macos
    ROJO_OS_SUFFIX := macos-aarch64
    LUNE_OS_SUFFIX := macos-aarch64
    SELENE_OS_SUFFIX := macos
    STYLUA_OS_SUFFIX := macos-aarch64
    TARMAC_OS_SUFFIX := macos
    RBXCLOUD_OS_SUFFIX := macos
    WALLY_OS_SUFFIX := macos
    MCP_OS_SUFFIX := macos
endif

# Default target
all: setup

# Setup targets
setup: setup-tools setup-plugins

setup-tools: bin/rojo bin/lune bin/selene bin/stylua bin/tarmac bin/rbxcloud bin/wally bin/rbx-studio-mcp

setup-plugins: install-rojo-plugin install-mcp-plugin
	@echo "Plugins installed to: $(ROBLOX_PLUGINS_DIR)"

# Download helper - reduces repetition
# Usage: $(call download,url,output)
define download
	@mkdir -p bin
	curl -fSL -o /tmp/download.zip "$(1)"
	unzip -o /tmp/download.zip -d bin/
	@test -f "$(2)" && chmod +x "$(2)" || true
	@rm -f /tmp/download.zip
endef

# Individual tool targets
bin/rojo:
	$(call download,https://github.com/rojo-rbx/rojo/releases/download/v$(ROJO_VERSION)/rojo-$(ROJO_VERSION)-$(ROJO_OS_SUFFIX).zip,bin/rojo)

bin/lune:
	$(call download,https://github.com/lune-org/lune/releases/download/v$(LUNE_VERSION)/lune-$(LUNE_VERSION)-$(LUNE_OS_SUFFIX).zip,bin/lune)

bin/selene:
	$(call download,https://github.com/Kampfkarren/selene/releases/download/$(SELENE_VERSION)/selene-$(SELENE_VERSION)-$(SELENE_OS_SUFFIX).zip,bin/selene)

bin/stylua:
	$(call download,https://github.com/JohnnyMorganz/StyLua/releases/download/v$(STYLUA_VERSION)/stylua-$(STYLUA_OS_SUFFIX).zip,bin/stylua)

bin/tarmac:
	$(call download,https://github.com/Roblox/tarmac/releases/download/v$(TARMAC_VERSION)/tarmac-$(TARMAC_OS_SUFFIX).zip,bin/tarmac)

bin/rbxcloud:
	$(call download,https://github.com/Sleitnick/rbxcloud/releases/download/v$(RBXCLOUD_VERSION)/rbxcloud-$(RBXCLOUD_VERSION)-$(RBXCLOUD_OS_SUFFIX).zip,bin/rbxcloud)

bin/wally:
	$(call download,https://github.com/UpliftGames/wally/releases/download/v$(WALLY_VERSION)/wally-v$(WALLY_VERSION)-$(WALLY_OS_SUFFIX).zip,bin/wally)

bin/rbx-studio-mcp:
ifeq ($(UNAME_S),Darwin)
	$(call download,https://github.com/$(MCP_SERVER_REPO)/releases/download/v$(MCP_SERVER_VERSION)/macOS-rbx-studio-mcp.zip,bin/rbx-studio-mcp)
	mv bin/RobloxStudioMCP.app/Contents/MacOS/rbx-studio-mcp bin/rbx-studio-mcp
	rm -rf bin/RobloxStudioMCP.app
else
	$(call download,https://github.com/$(MCP_SERVER_REPO)/releases/download/v$(MCP_SERVER_VERSION)/rbx-studio-mcp-$(MCP_OS_SUFFIX).zip,bin/rbx-studio-mcp)
endif

# MCP Plugin (download from same release)
bin/MCPStudioPlugin.rbxm:
	@mkdir -p bin
	curl -sL https://github.com/$(MCP_SERVER_REPO)/releases/download/v$(MCP_SERVER_VERSION)/MCPStudioPlugin.rbxm -o bin/MCPStudioPlugin.rbxm

# Plugin installation
install-rojo-plugin: bin/rojo
	@if [ -z "$(ROBLOX_PLUGINS_DIR)" ]; then \
		echo "Error: Could not detect Roblox plugins directory."; \
		echo "Set ROBLOX_PLUGINS_DIR in .env"; \
		exit 1; \
	fi
	@mkdir -p "$(ROBLOX_PLUGINS_DIR)"
	curl -fSL -o "$(ROBLOX_PLUGINS_DIR)/Rojo.rbxm" \
		"https://github.com/rojo-rbx/rojo/releases/download/v$(ROJO_VERSION)/Rojo.rbxm"
	@echo "Installed Rojo plugin"

install-mcp-plugin: bin/MCPStudioPlugin.rbxm
	@if [ -z "$(ROBLOX_PLUGINS_DIR)" ]; then \
		echo "Error: Could not detect Roblox plugins directory."; \
		echo "Set ROBLOX_PLUGINS_DIR in .env"; \
		exit 1; \
	fi
	@mkdir -p "$(ROBLOX_PLUGINS_DIR)"
	cp bin/MCPStudioPlugin.rbxm "$(ROBLOX_PLUGINS_DIR)/"
	@echo "Installed MCP plugin"

# MCP Server management
mcp-start:
	@./scripts/start-mcp-server.sh start

mcp-stop:
	@./scripts/start-mcp-server.sh stop

# Development
serve: bin/rojo
	./bin/rojo serve

build: bin/rojo
	./bin/rojo build -o build.rbxl

publish: build bin/rbxcloud
	@if [ -z "$(ROBLOX_OPEN_CLOUD_API_KEY)" ]; then \
		echo "Error: ROBLOX_OPEN_CLOUD_API_KEY not set. See .env.example"; \
		exit 1; \
	fi
	@./bin/rbxcloud experience publish \
		--filename build.rbxl \
		--place-id $(ROBLOX_PLACE_ID) \
		--universe-id $(ROBLOX_UNIVERSE_ID) \
		--version-type published \
		--api-key $(ROBLOX_OPEN_CLOUD_API_KEY)

lint: bin/selene
	./bin/selene src/

format: bin/stylua
	./bin/stylua src/

check: bin/selene bin/stylua
	./bin/selene src/
	./bin/stylua --check src/

# Documentation
setup-docs: docs/creator-docs

docs/creator-docs:
	@mkdir -p docs
	git clone --depth 1 https://github.com/Roblox/creator-docs.git /tmp/creator-docs-clone
	mv /tmp/creator-docs-clone/content/en-us docs/creator-docs
	rm -rf /tmp/creator-docs-clone
	@echo "Downloaded Roblox creator docs to docs/creator-docs/"

verify:
	@./scripts/verify.sh

setup-hooks:
	git config core.hooksPath .githooks
	@echo "Git hooks installed. Pre-commit will run 'make check' before each commit."

clean:
	rm -rf bin/
