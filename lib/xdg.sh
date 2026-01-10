#!/usr/bin/env bash
#
# xdg.sh - XDG Base Directory Specification helpers
#
# Provides functions to respect the XDG Base Directory Specification
# (https://specifications.freedesktop.org/basedir-spec/latest/)
# with sensible fallbacks for macOS and other systems.
#
# Environment Variables:
#   XDG_CONFIG_HOME    - User config directory (default: ~/.config)
#   XDG_DATA_HOME      - User data directory (default: ~/.local/share)
#   XDG_CACHE_HOME     - User cache directory (default: ~/.cache)
#

# Get XDG config home directory
# Returns: path to config directory (defaults to ~/.config)
xdg_config_home() {
    if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
        echo "$XDG_CONFIG_HOME"
    else
        echo "${HOME}/.config"
    fi
}

# Get XDG data home directory
# Returns: path to data directory (defaults to ~/.local/share)
xdg_data_home() {
    if [[ -n "${XDG_DATA_HOME:-}" ]]; then
        echo "$XDG_DATA_HOME"
    else
        echo "${HOME}/.local/share"
    fi
}

# Get XDG cache home directory
# Returns: path to cache directory (defaults to ~/.cache)
xdg_cache_home() {
    if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
        echo "$XDG_CACHE_HOME"
    else
        echo "${HOME}/.cache"
    fi
}

# Ensure curb directories exist
# Creates standard curb directories:
#   - config: $(xdg_config_home)/curb
#   - data: $(xdg_data_home)/curb
#   - logs: $(xdg_data_home)/curb/logs
#   - cache: $(xdg_cache_home)/curb
curb_ensure_dirs() {
    local config_dir
    local data_dir
    local logs_dir
    local cache_dir

    config_dir="$(xdg_config_home)/curb"
    data_dir="$(xdg_data_home)/curb"
    logs_dir="${data_dir}/logs"
    cache_dir="$(xdg_cache_home)/curb"

    # Create directories if they don't exist
    mkdir -p "$config_dir"
    mkdir -p "$logs_dir"
    mkdir -p "$cache_dir"
}

# Get curb config directory
# Returns: path to curb config directory
curb_config_dir() {
    echo "$(xdg_config_home)/curb"
}

# Get curb data directory
# Returns: path to curb data directory
curb_data_dir() {
    echo "$(xdg_data_home)/curb"
}

# Get curb logs directory
# Returns: path to curb logs directory
curb_logs_dir() {
    echo "$(xdg_data_home)/curb/logs"
}

# Get curb cache directory
# Returns: path to curb cache directory
curb_cache_dir() {
    echo "$(xdg_cache_home)/curb"
}
