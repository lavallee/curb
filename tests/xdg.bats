#!/usr/bin/env bats

# Test suite for lib/xdg.sh

# Load the test helper
load test_helper

# Load the xdg library
setup() {
    source "${PROJECT_ROOT}/lib/xdg.sh"
}

# Test xdg_config_home with default
@test "xdg_config_home returns ~/.config by default" {
    unset XDG_CONFIG_HOME
    result=$(xdg_config_home)
    [[ "$result" == "${HOME}/.config" ]]
}

# Test xdg_config_home with environment variable
@test "xdg_config_home respects XDG_CONFIG_HOME" {
    export XDG_CONFIG_HOME="/custom/config"
    result=$(xdg_config_home)
    [[ "$result" == "/custom/config" ]]
}

# Test xdg_data_home with default
@test "xdg_data_home returns ~/.local/share by default" {
    unset XDG_DATA_HOME
    result=$(xdg_data_home)
    [[ "$result" == "${HOME}/.local/share" ]]
}

# Test xdg_data_home with environment variable
@test "xdg_data_home respects XDG_DATA_HOME" {
    export XDG_DATA_HOME="/custom/data"
    result=$(xdg_data_home)
    [[ "$result" == "/custom/data" ]]
}

# Test xdg_cache_home with default
@test "xdg_cache_home returns ~/.cache by default" {
    unset XDG_CACHE_HOME
    result=$(xdg_cache_home)
    [[ "$result" == "${HOME}/.cache" ]]
}

# Test xdg_cache_home with environment variable
@test "xdg_cache_home respects XDG_CACHE_HOME" {
    export XDG_CACHE_HOME="/custom/cache"
    result=$(xdg_cache_home)
    [[ "$result" == "/custom/cache" ]]
}

# Test curb_config_dir
@test "curb_config_dir returns correct path" {
    unset XDG_CONFIG_HOME
    result=$(curb_config_dir)
    [[ "$result" == "${HOME}/.config/curb" ]]
}

# Test curb_data_dir
@test "curb_data_dir returns correct path" {
    unset XDG_DATA_HOME
    result=$(curb_data_dir)
    [[ "$result" == "${HOME}/.local/share/curb" ]]
}

# Test curb_logs_dir
@test "curb_logs_dir returns correct path" {
    unset XDG_DATA_HOME
    result=$(curb_logs_dir)
    [[ "$result" == "${HOME}/.local/share/curb/logs" ]]
}

# Test curb_cache_dir
@test "curb_cache_dir returns correct path" {
    unset XDG_CACHE_HOME
    result=$(curb_cache_dir)
    [[ "$result" == "${HOME}/.cache/curb" ]]
}

# Test curb_ensure_dirs creates directories
@test "curb_ensure_dirs creates config directory" {
    # Use temp dir for testing
    export XDG_CONFIG_HOME="${BATS_TMPDIR}/test_config"
    export XDG_DATA_HOME="${BATS_TMPDIR}/test_data"
    export XDG_CACHE_HOME="${BATS_TMPDIR}/test_cache"

    # Clean up any existing directories
    rm -rf "${BATS_TMPDIR}/test_config" "${BATS_TMPDIR}/test_data" "${BATS_TMPDIR}/test_cache"

    # Call the function
    curb_ensure_dirs

    # Verify config directory exists
    [[ -d "${BATS_TMPDIR}/test_config/curb" ]]
}

@test "curb_ensure_dirs creates data directory" {
    # Use temp dir for testing
    export XDG_CONFIG_HOME="${BATS_TMPDIR}/test_config"
    export XDG_DATA_HOME="${BATS_TMPDIR}/test_data"
    export XDG_CACHE_HOME="${BATS_TMPDIR}/test_cache"

    # Clean up any existing directories
    rm -rf "${BATS_TMPDIR}/test_config" "${BATS_TMPDIR}/test_data" "${BATS_TMPDIR}/test_cache"

    # Call the function
    curb_ensure_dirs

    # Verify data directory exists
    [[ -d "${BATS_TMPDIR}/test_data/curb" ]]
}

@test "curb_ensure_dirs creates logs directory" {
    # Use temp dir for testing
    export XDG_CONFIG_HOME="${BATS_TMPDIR}/test_config"
    export XDG_DATA_HOME="${BATS_TMPDIR}/test_data"
    export XDG_CACHE_HOME="${BATS_TMPDIR}/test_cache"

    # Clean up any existing directories
    rm -rf "${BATS_TMPDIR}/test_config" "${BATS_TMPDIR}/test_data" "${BATS_TMPDIR}/test_cache"

    # Call the function
    curb_ensure_dirs

    # Verify logs directory exists
    [[ -d "${BATS_TMPDIR}/test_data/curb/logs" ]]
}

@test "curb_ensure_dirs creates cache directory" {
    # Use temp dir for testing
    export XDG_CONFIG_HOME="${BATS_TMPDIR}/test_config"
    export XDG_DATA_HOME="${BATS_TMPDIR}/test_data"
    export XDG_CACHE_HOME="${BATS_TMPDIR}/test_cache"

    # Clean up any existing directories
    rm -rf "${BATS_TMPDIR}/test_config" "${BATS_TMPDIR}/test_data" "${BATS_TMPDIR}/test_cache"

    # Call the function
    curb_ensure_dirs

    # Verify cache directory exists
    [[ -d "${BATS_TMPDIR}/test_cache/curb" ]]
}
