#!/usr/bin/env bash

# test_helper.bash - Helper functions for BATS tests

# Load the script under test
load_script() {
    local script_path="$1"
    # shellcheck source=/dev/null
    source "$script_path"
}

# Mock command function
mock_command() {
    local cmd=$1
    local mock_func=${2:-}
    
    # Create a function to handle the mock
    if [[ -n "$mock_func" ]]; then
        eval "$cmd() {
            if [[ \$1 == \"api\" ]]; then
                shift
                \$mock_func \"\$@\"
            else
                echo \"Mock for $cmd called with: \$*\"
            fi
        }"
    else
        # Default mock that just echoes the command and arguments
        eval "$cmd() {
            echo \"Mock for $cmd called with: \$*\"
            return 0
        }"
    fi
}

# Unmock command function
unmock_command() {
    local cmd=$1
    unset -f "$cmd"
}

# Mock environment variables
mock_env() {
    local var="$1"
    local value="$2"
    eval "export $var=\"$value\""
}

# Setup function for tests
setup() {
    # Create temporary directory for test files
    TEST_TEMP_DIR=$(mktemp -d)
    export TEST_TEMP_DIR
    
    # Mock default environment variables
    mock_env "GITHUB_TOKEN" "test-token"
    mock_env "DEBUG" "false"
}

# Teardown function for tests
teardown() {
    # Clean up temporary directory
    if [[ -d "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    # Unset mocked functions and variables
    unset -f gh 2>/dev/null || true
    unset -f jq 2>/dev/null || true
    unset GITHUB_TOKEN 2>/dev/null || true
    unset DEBUG 2>/dev/null || true
}

# Assert that a command succeeds
assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Command failed with status $status"
        echo "Output: $output"
        return 1
    fi
}

# Assert that a command fails
assert_failure() {
    if [[ "$status" -eq 0 ]]; then
        echo "Command succeeded unexpectedly"
        echo "Output: $output"
        return 1
    fi
}

# Assert that output contains a string
assert_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Output does not contain '$expected'"
        echo "Actual output: $output"
        return 1
    fi
}

# Assert that output does not contain a string
assert_output_not_contains() {
    local unexpected="$1"
    if [[ "$output" == *"$unexpected"* ]]; then
        echo "Output contains unexpected string '$unexpected'"
        echo "Actual output: $output"
        return 1
    fi
}

# Test environment setup
setup_test_env() {
    # Set up test environment variables
    export SOURCE_ORG="test-source-org"
    export TARGET_ORG="test-target-org"
    export REPO_NAME="test-repo"
    export GITHUB_TOKEN="test-token"
    export LOG_LEVEL_INFO=1
    export LOG_LEVEL_ERROR=3
    export PARALLEL_JOBS=2
}

# Test environment cleanup
cleanup_test_env() {
    # Clean up test environment variables
    unset SOURCE_ORG 2>/dev/null || true
    unset TARGET_ORG 2>/dev/null || true
    unset REPO_NAME 2>/dev/null || true
    unset GITHUB_TOKEN 2>/dev/null || true
    unset LOG_LEVEL_INFO 2>/dev/null || true
    unset LOG_LEVEL_ERROR 2>/dev/null || true
    unset PARALLEL_JOBS 2>/dev/null || true
}

# Log function for tests
log() {
    local level=$1
    shift
    local message=$*
    echo "[$level] $message"
} 