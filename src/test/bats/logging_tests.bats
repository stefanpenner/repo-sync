#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# shellcheck source=./test_helper.bash
source "$BATS_TEST_DIRNAME/test_helper.bash"

# Set up test environment before loading the script
setup_test_env

# Load the main script
# shellcheck source=../../lib/logging.sh
source "$BATS_TEST_DIRNAME/../../lib/logging.sh"

@test "log under LOG_LEVEL_DEBUG" {
  # Test at DEBUG level (should show all messages)
  export LOG_LEVEL=$LOG_LEVEL_DEBUG
  
  run --separate-stderr log $LOG_LEVEL_DEBUG "debug message"
  assert_success
  assert_stderr_contains "DEBUG: debug message"

  
  run --separate-stderr log $LOG_LEVEL_INFO "info message"
  assert_success
  assert_stderr_contains "INFO: info message"
  
  run --separate-stderr log $LOG_LEVEL_WARN "warn message"
  assert_success
  assert_stderr_contains "WARN: warn message"
  
  run --separate-stderr log $LOG_LEVEL_ERROR "error message"
  assert_success
  assert_stderr_contains "ERROR: error message"
}

@test "log under LOG_LEVEL_INFO" {
  # Test at INFO level (should not show DEBUG)
  export LOG_LEVEL=$LOG_LEVEL_INFO
  
  run --separate-stderr log $LOG_LEVEL_DEBUG "debug message"
  assert_success
  assert_stderr_not_contains "DEBUG: debug message"
  
  run --separate-stderr log $LOG_LEVEL_INFO "info message"
  assert_success
  assert_stderr_contains "INFO: info message"
  
  run --separate-stderr log $LOG_LEVEL_WARN "warn message"
  assert_success
  assert_stderr_contains "WARN: warn message"
  
  run --separate-stderr log $LOG_LEVEL_ERROR "error message"
  assert_success
  assert_stderr_contains "ERROR: error message"
}

@test "log under LOG_LEVEL_WARN" {
  # Test at WARN level (should only show WARN and ERROR)
  export LOG_LEVEL=$LOG_LEVEL_WARN
  
  run --separate-stderr log $LOG_LEVEL_DEBUG "debug message"
  assert_success
  assert_stderr_not_contains "DEBUG: debug message"
  
  run --separate-stderr log $LOG_LEVEL_INFO "info message"
  assert_success
  assert_stderr_not_contains "INFO: info message"
  
  run --separate-stderr log $LOG_LEVEL_WARN "warn message"
  assert_success
  assert_stderr_contains "WARN: warn message"
  
  run --separate-stderr log $LOG_LEVEL_ERROR "error message"
  assert_success
  assert_stderr_contains "ERROR: error message"
}

@test "log under LOG_LEVEL_ERROR" {
  # Test at ERROR level (should only show ERROR)
  export LOG_LEVEL=$LOG_LEVEL_ERROR
  
  run --separate-stderr log $LOG_LEVEL_DEBUG "debug message"
  assert_success
  assert_stderr_not_contains "DEBUG: debug message"
  
  run --separate-stderr log $LOG_LEVEL_INFO "info message"
  assert_success
  assert_stderr_not_contains "INFO: info message"
  
  run --separate-stderr log $LOG_LEVEL_WARN "warn message"
  assert_success
  assert_stderr_not_contains "WARN: warn message"
  
  run --separate-stderr log $LOG_LEVEL_ERROR "error message"
  assert_success
  assert_stderr_contains "ERROR: error message"
}

@test "test logging" {
    run --separate-stderr some_command
    assert_stderr_contains "ome_command: command not found"
}