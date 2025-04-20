# Testing Documentation

This document provides detailed information about the testing framework and procedures for the GitHub Repository Synchronization Script.

## Testing Framework

The project uses BATS (Bash Automated Testing System) for testing. BATS provides a simple way to write and run tests for shell scripts.

### Dependencies

- BATS 1.7.0 or later
- shellcheck 0.8.0 or later
- jq 1.6 or later
- GitHub CLI (gh) 2.0.0 or later

## Test Structure

Tests are organized in the following structure:

```
src/test/
├── bats/
│   ├── basic_tests.bats      # Basic functionality tests
│   ├── api_tests.bats        # GitHub API interaction tests
│   ├── error_tests.bats      # Error handling tests
│   └── performance_tests.bats # Performance tests
└── integration/
    └── full_workflow_tests.bats # End-to-end tests
```

## Running Tests

### Basic Test Suite

```bash
# Run all tests
bats src/test/bats/

# Run specific test file
bats src/test/bats/basic_tests.bats

# Run specific test
bats src/test/bats/basic_tests.bats -f "test name"
```

### Integration Tests

```bash
# Run all integration tests
bats src/test/integration/

# Run specific integration test
bats src/test/integration/full_workflow_tests.bats
```

### Test Coverage

```bash
# Generate coverage report
./scripts/coverage.sh
```

## Test Categories

### 1. Unit Tests

Unit tests focus on testing individual functions in isolation.

**Example:**
```bash
@test "log function formats messages correctly" {
    run log $LOG_LEVEL_INFO "test message"
    assert_success
    assert_output_contains "INFO: test message"
}
```

### 2. Integration Tests

Integration tests verify that different components work together correctly.

**Example:**
```bash
@test "full PR synchronization workflow" {
    # Setup test repositories
    setup_test_repositories
    
    # Run synchronization
    run sync_pull_request "source/repo" "target/repo"
    
    # Verify results
    assert_success
    verify_synchronized_pr
}
```

### 3. Error Tests

Error tests verify proper error handling and reporting.

**Example:**
```bash
@test "handles invalid GitHub token" {
    mock_gh "auth status" "error: authentication required"
    run validate_github_token
    assert_failure
    assert_output_contains "Invalid GitHub token"
}
```

### 4. Performance Tests

Performance tests verify that the script meets performance requirements.

**Example:**
```bash
@test "processes PRs within rate limit" {
    start_time=$(date +%s)
    run sync_multiple_prs 100
    end_time=$(date +%s)
    
    duration=$((end_time - start_time))
    assert [ "$duration" -lt 600 ] # Should complete within 10 minutes
}
```

## Mocking

The test framework includes utilities for mocking external dependencies:

### GitHub CLI Mocking

```bash
# Mock successful authentication
mock_gh "auth status" "✓ Logged in to github.com as test-user"

# Mock API response
mock_gh "api /repos/owner/repo/pulls" '{"number": 123, "title": "Test PR"}'
```

### Environment Mocking

```bash
# Mock environment variables
mock_env "GITHUB_TOKEN" "test-token"
mock_env "DEBUG" "true"
```

## Test Helper Functions

The test framework provides helper functions for common testing tasks:

### Assertions

```bash
# Check command success
assert_success

# Check command failure
assert_failure

# Check output contains string
assert_output_contains "expected string"

# Check output does not contain string
assert_output_not_contains "unexpected string"
```

### Setup and Teardown

```bash
setup() {
    # Setup test environment
    create_test_directory
    mock_dependencies
}

teardown() {
    # Clean up test environment
    remove_test_directory
    unmock_dependencies
}
```

## Best Practices

1. **Test Organization**
   - Group related tests together
   - Use descriptive test names
   - Keep tests focused and simple

2. **Mocking**
   - Mock external dependencies
   - Use realistic mock data
   - Document mock behavior

3. **Error Handling**
   - Test error conditions
   - Verify error messages
   - Check error codes

4. **Performance**
   - Test with realistic data sizes
   - Monitor resource usage
   - Set performance benchmarks

## Continuous Integration

Tests are run automatically in CI:

1. **Pre-commit Hooks**
   - Run basic tests
   - Check code style
   - Verify documentation

2. **CI Pipeline**
   - Run full test suite
   - Generate coverage report
   - Check performance metrics

## Troubleshooting Tests

### Common Issues

1. **Test Failure**
   - Check mock setup
   - Verify environment
   - Review error messages

2. **Performance Issues**
   - Check resource limits
   - Review test data size
   - Monitor system load

3. **Mock Problems**
   - Verify mock behavior
   - Check mock data
   - Review mock setup

### Debugging Tips

1. **Enable Debug Output**
   ```bash
   DEBUG=true bats test_file.bats
   ```

2. **View Test Output**
   ```bash
   bats -p test_file.bats
   ```

3. **Check Mock Behavior**
   ```bash
   mock_gh "command" "response" --debug
   ```

## Adding New Tests

1. **Choose Test Category**
   - Unit test
   - Integration test
   - Error test
   - Performance test

2. **Write Test**
   - Follow test structure
   - Use helper functions
   - Include comments

3. **Verify Test**
   - Run locally
   - Check coverage
   - Review output

4. **Add to CI**
   - Update test suite
   - Verify CI runs
   - Monitor results 