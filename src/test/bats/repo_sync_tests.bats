#!/usr/bin/env bats

# shellcheck source=./test_helper.bash
source "$BATS_TEST_DIRNAME/test_helper.bash"

# Set up test environment before loading the script
setup_test_env

# Load the main script
# shellcheck source=../../bin/repo-sync.sh
source "$BATS_TEST_DIRNAME/../../bin/repo-sync.sh"

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
  export LOG_LEVEL=$LOG_LEVEL_DEBUG  # Set log level to DEBUG
  gh() {
    if [[ "$1" == "auth" && "$2" == "status" ]]; then
      echo "✓ Logged in to github.com as test-user"
      return 0
    fi
    return 1
  }
  
  run main --source-org test --target-org test --repo test
  assert_success
  
  # Check for debug output in dependency checking
  assert_output_contains "DEBUG: Checking dependencies"
  assert_output_contains "DEBUG: Found command: bash"
  assert_output_contains "DEBUG: Found command: gh"
  assert_output_contains "DEBUG: Found command: jq"
  assert_output_contains "DEBUG: Bash version OK:"
  assert_output_contains "DEBUG: All dependencies found"
  
  # Check for other debug messages
  assert_output_contains "DEBUG: Parsing arguments"
  
  # Check for info messages (should still appear in debug mode)
  assert_output_contains "INFO: Starting GitHub repository synchronization"
}