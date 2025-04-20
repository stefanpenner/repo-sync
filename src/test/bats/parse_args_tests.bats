#!/usr/bin/env bats

# shellcheck source=./test_helper.bash
source "$BATS_TEST_DIRNAME/test_helper.bash"

# Set up test environment before loading the script
setup_test_env

# Load the main script
# shellcheck source=../../bin/repo-sync.sh
source "$BATS_TEST_DIRNAME/../../bin/repo-sync.sh"


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
  assert_output_contains "Missing required argument: --repo"
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
