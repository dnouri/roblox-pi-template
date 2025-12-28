#!/bin/bash
# Detect Roblox Studio plugins directory
# Supports macOS, Linux (Vinegar/Wine)

set -e

# Check OS type
case "$(uname -s)" in
    Darwin*)
        # macOS
        if [ -d "$HOME/Documents/Roblox/Plugins" ]; then
            echo "$HOME/Documents/Roblox/Plugins"
            exit 0
        fi
        # Fallback to Library location (older versions)
        if [ -d "$HOME/Library/Roblox/Plugins" ]; then
            echo "$HOME/Library/Roblox/Plugins"
            exit 0
        fi
        ;;
    Linux*)
        # Try Vinegar/Flatpak first (most common on Linux)
        VINEGAR_BASE="$HOME/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users"
        if [ -d "$VINEGAR_BASE" ]; then
            for user_dir in "$VINEGAR_BASE"/*/; do
                roblox_dir="${user_dir}AppData/Local/Roblox"
                if [ -d "$roblox_dir" ]; then
                    echo "${user_dir}AppData/Local/Roblox/Plugins"
                    exit 0
                fi
            done
        fi

        # Try standard Wine prefix
        WINE_PREFIX="${WINEPREFIX:-$HOME/.wine}"
        WINE_ROBLOX="$WINE_PREFIX/drive_c/users/$USER/AppData/Local/Roblox"
        if [ -d "$WINE_ROBLOX" ]; then
            echo "$WINE_ROBLOX/Plugins"
            exit 0
        fi
        ;;
esac

# Not found
exit 1
