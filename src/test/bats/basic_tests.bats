#!/usr/bin/env bats

# shellcheck source=./test_helper.bash
source "$BATS_TEST_DIRNAME/test_helper.bash"

# Set up test environment before loading the script
setup_test_env

# shellcheck source=../../lib/sync_functions.sh
source "$BATS_TEST_DIRNAME/../../lib/sync_functions.sh"

# Load the main script
# shellcheck source=../../bin/github-sync.sh
source "$BATS_TEST_DIRNAME/../../bin/github-sync.sh"

setup() {
  mock_command gh
  mock_command jq
  mock_command command
}

teardown() {
  cleanup_test_env
  unmock_command gh
  unmock_command jq
  unmock_command command
}

@test "parse_args handles all required arguments" {
  # Set up test arguments
  local args=("--source-org" "test-source" "--target-org" "test-target" "--repo" "test-repo")
  
  # Call parse_args with the test arguments
  parse_args "${args[@]}"
  
  # Check that the variables were set correctly
  [ "$SOURCE_ORG" = "test-source" ]
  [ "$TARGET_ORG" = "test-target" ]
  [ "$REPO_NAME" = "test-repo" ]
}

@test "parse_args fails with missing required arguments" {
  # Set up test arguments with missing required arg
  local args=("--source-org" "test-source" "--target-org" "test-target")
  
  # Call parse_args and expect it to fail
  run parse_args "${args[@]}"
  
  assert_failure
  assert_output_contains "Missing required arguments"
}

@test "parse_args handles optional PR number" {
  # Set up test arguments with PR number
  local args=("--source-org" "test-source" "--target-org" "test-target" "--repo" "test-repo" "--pr" "123")
  
  # Call parse_args with the test arguments
  parse_args "${args[@]}"
  
  # Check that the PR number was set correctly
  [ "$PR_NUMBER" = "123" ]
}

@test "parse_args handles configuration file" {
  # Set up test arguments with config file
  local args=("--source-org" "test-source" "--target-org" "test-target" "--repo" "test-repo" "--config" "test-config.yaml")
  
  # Call parse_args with the test arguments
  parse_args "${args[@]}"
  
  # Check that the config file was set correctly
  [ "$CONFIG_FILE" = "test-config.yaml" ]
}

@test "parse_args handles parallel jobs" {
  # Set up test arguments with parallel jobs
  local args=("--source-org" "test-source" "--target-org" "test-target" "--repo" "test-repo" "--parallel" "8")
  
  # Call parse_args with the test arguments
  parse_args "${args[@]}"
  
  # Check that the parallel jobs was set correctly
  [ "$PARALLEL_JOBS" = "8" ]
}

@test "show_help displays usage information" {
  run show_help
  
  assert_success
  assert_output_contains "Usage:"
  assert_output_contains "Options:"
  assert_output_contains "Environment Variables:"
}

@test "script requires jq command" {
  # Mock command to return failure for jq
  command() {
    if [[ "$1" == "-v" && "$2" == "jq" ]]; then
      return 1
    fi
    return 0
  }
  
  run check_dependencies
  assert_failure
  assert_output_contains "Missing dependencies: jq"
}

@test "script requires GITHUB_TOKEN" {
  unset GITHUB_TOKEN
  run validate_github_token
  assert_failure
  assert_output_contains "GITHUB_TOKEN environment variable is not set"
}

@test "script validates GitHub token" {
  gh() {
    if [[ "$1" == "auth" && "$2" == "status" ]]; then
      echo "error: authentication required"
      return 1
    fi
    return 1
  }
  
  run validate_github_token
  assert_failure
  assert_output_contains "Invalid GitHub token or insufficient permissions"
}

@test "script runs successfully with valid environment" {
  gh() {
    if [[ "$1" == "auth" && "$2" == "status" ]]; then
      echo "✓ Logged in to github.com as test-user"
      return 0
    fi
    return 1
  }
  
  run main --source-org test --target-org test --repo test
  assert_success
  assert_output_contains "Starting GitHub repository synchronization"
}

@test "debug mode enables verbose output" {
  export DEBUG="true"
  gh() {
    if [[ "$1" == "auth" && "$2" == "status" ]]; then
      echo "✓ Logged in to github.com as test-user"
      return 0
    fi
    return 1
  }
  
  run main --source-org test --target-org test --repo test
  assert_success
  # The + before the command indicates debug mode is enabled
  assert_output_contains "+"
}

@test "logging functions work correctly" {
  # Test debug logging
  run log $LOG_LEVEL_DEBUG "debug message"
  assert_success
  assert_output_contains "DEBUG: debug message"
  
  # Test info logging
  run log $LOG_LEVEL_INFO "info message"
  assert_success
  assert_output_contains "INFO: info message"
  
  # Test warn logging
  run log $LOG_LEVEL_WARN "warn message"
  assert_success
  assert_output_contains "WARN: warn message"
  
  # Test error logging
  run log $LOG_LEVEL_ERROR "error message"
  assert_success
  assert_output_contains "ERROR: error message"
}

