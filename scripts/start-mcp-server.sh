#!/bin/bash
# Start the MCP server for Studio interaction
# The server listens on port 44755 for the Studio plugin

set -e

MCP_PORT=44755
MCP_BIN="./bin/rbx-studio-mcp"
PID_FILE="/tmp/rbx-studio-mcp.pid"
LOG_FILE="/tmp/rbx-studio-mcp.log"

case "${1:-start}" in
    start)
        # Check if already running
        if [ -f "$PID_FILE" ]; then
            pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                echo "MCP server already running (PID: $pid)"
                exit 0
            fi
            rm -f "$PID_FILE"
        fi

        # Check if port is in use
        if command -v nc >/dev/null && nc -z 127.0.0.1 $MCP_PORT 2>/dev/null; then
            echo "Port $MCP_PORT already in use"
            exit 0
        fi

        # Verify binary exists
        if [ ! -x "$MCP_BIN" ]; then
            echo "Error: $MCP_BIN not found. Run 'make setup' first."
            exit 1
        fi

        # Start server in HTTP-only mode (no MCP stdio needed)
        nohup "$MCP_BIN" --http-only > "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        echo "MCP server started (PID: $!)"

        # Wait for it to be ready
        for i in {1..10}; do
            if command -v nc >/dev/null && nc -z 127.0.0.1 $MCP_PORT 2>/dev/null; then
                echo "MCP server ready on port $MCP_PORT"
                exit 0
            fi
            sleep 0.5
        done

        echo "Warning: MCP server started but port not responding yet"
        ;;

    stop)
        if [ -f "$PID_FILE" ]; then
            pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                echo "MCP server stopped (PID: $pid)"
            else
                echo "MCP server not running"
            fi
            rm -f "$PID_FILE"
        else
            echo "MCP server not running (no PID file)"
        fi
        ;;

    status)
        if [ -f "$PID_FILE" ]; then
            pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                echo "MCP server running (PID: $pid)"
                if command -v nc >/dev/null && nc -z 127.0.0.1 $MCP_PORT 2>/dev/null; then
                    echo "Port $MCP_PORT: listening"
                else
                    echo "Port $MCP_PORT: not responding"
                fi
                exit 0
            fi
        fi
        echo "MCP server not running"
        exit 1
        ;;

    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
