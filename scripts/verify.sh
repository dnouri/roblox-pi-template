#!/bin/bash
# Verify that the development environment is set up correctly

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }

echo "Checking Roblox Pi development environment..."
echo ""

errors=0

# Check CLI tools
echo "CLI Tools:"
for tool in rojo lune selene stylua rbxcloud wally rbx-studio-mcp; do
    if [ -x "bin/$tool" ]; then
        version=$(./bin/$tool --version 2>/dev/null | head -1 || echo "unknown")
        ok "$tool ($version)"
    else
        fail "$tool not found - run 'make setup-tools'"
        errors=$((errors + 1))
    fi
done
echo ""

# Check plugins directory
echo "Studio Plugins:"
PLUGINS_DIR=$(./scripts/detect-plugins-dir.sh 2>/dev/null || echo "")
if [ -z "$PLUGINS_DIR" ]; then
    warn "Could not detect plugins directory"
else
    if [ -f "$PLUGINS_DIR/Rojo.rbxm" ]; then
        ok "Rojo plugin installed"
    else
        fail "Rojo plugin not found - run 'make setup-plugins'"
        errors=$((errors + 1))
    fi
    
    if [ -f "$PLUGINS_DIR/MCPStudioPlugin.rbxm" ]; then
        ok "MCP plugin installed"
    else
        fail "MCP plugin not found - run 'make setup-plugins'"
        errors=$((errors + 1))
    fi
fi
echo ""

# Check environment variables
echo "Environment:"
if [ -f .env ]; then
    source .env 2>/dev/null || true
    
    if [ -n "$ROBLOX_OPEN_CLOUD_API_KEY" ]; then
        ok "API key configured"
    else
        warn "API key not set (needed for publishing/assets)"
    fi
    
    if [ -n "$ROBLOX_UNIVERSE_ID" ] && [ -n "$ROBLOX_PLACE_ID" ]; then
        ok "Universe/Place IDs configured"
    else
        warn "Universe/Place IDs not set (needed for publishing)"
    fi
else
    warn ".env file not found (copy from .env.example for publishing)"
fi
echo ""

# Check MCP server status
echo "MCP Server:"
if [ -f /tmp/rbx-studio-mcp.pid ]; then
    pid=$(cat /tmp/rbx-studio-mcp.pid)
    if kill -0 "$pid" 2>/dev/null; then
        ok "MCP server running (PID: $pid)"
    else
        warn "MCP server not running - start with 'make mcp-start'"
    fi
else
    warn "MCP server not running - start with 'make mcp-start'"
fi
echo ""

# Check documentation
echo "Documentation:"
if [ -d "docs/creator-docs" ]; then
    ok "Roblox creator docs downloaded"
else
    warn "Creator docs not found - run 'make setup-docs'"
fi
echo ""

# Summary
echo "---"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}Environment ready!${NC}"
    echo ""
    echo "Next steps:"
    echo "  make serve     # Start Rojo live sync"
    echo "  make mcp-start # Start MCP server for live Studio interaction"
else
    echo -e "${RED}Found $errors error(s).${NC} Fix them and run 'make verify' again."
    exit 1
fi
