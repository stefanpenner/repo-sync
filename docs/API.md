# API Documentation

This document provides detailed information about the GitHub Repository Synchronization Script's API and interfaces.

## Core Functions

### `main()`
The main entry point of the script.

**Parameters:**
- Command line arguments (see [Command Line Arguments](#command-line-arguments))

**Returns:**
- 0 on success
- Non-zero on failure

**Example:**
```bash
./github-sync.sh --source-org source-org --target-org target-org --repo repo-name
```

### `log(level, message)`
Logs a message with the specified level.

**Parameters:**
- `level`: Log level (DEBUG, INFO, WARN, ERROR)
- `message`: Message to log

**Example:**
```bash
log $LOG_LEVEL_INFO "Starting synchronization"
```

### `error(message, [exit_code])`
Logs an error message and exits with the specified code.

**Parameters:**
- `message`: Error message
- `exit_code`: Optional exit code (default: 1)

**Example:**
```bash
error "Invalid configuration" 2
```

### `check_dependencies()`
Checks for required dependencies.

**Returns:**
- 0 if all dependencies are present
- Non-zero if dependencies are missing

**Example:**
```bash
check_dependencies
```

### `validate_github_token()`
Validates the GitHub token.

**Returns:**
- 0 if token is valid
- Non-zero if token is invalid

**Example:**
```bash
validate_github_token
```

## Command Line Arguments

The script accepts the following command line arguments:

- `--source-org`: Source organization name (required)
- `--target-org`: Target organization name (required)
- `--repo`: Repository name (required)
- `--pr`: Specific pull request number (optional)
- `--config`: Path to configuration file (optional)
- `--debug`: Enable debug mode (optional)
- `--help`: Show help message (optional)

## Environment Variables

The script uses the following environment variables:

- `GITHUB_TOKEN`: GitHub personal access token (required)
- `DEBUG`: Set to "true" to enable debug mode (optional)
- `LOG_LEVEL`: Log level (DEBUG, INFO, WARN, ERROR) (optional)

## Configuration File

The script can be configured using a YAML configuration file. Default location: `~/.github-sync/config.yaml`

**Example configuration:**
```yaml
github_token: your-github-token
log_level: INFO
default_source_org: your-source-org
default_target_org: your-target-org
```

## Error Codes

The script uses the following error codes:

- 0: Success
- 1: General error
- 2: Configuration error
- 3: Dependency error
- 4: GitHub API error
- 5: Rate limit exceeded
- 6: Network error
- 7: Permission error

## Rate Limiting

The script implements rate limiting handling for GitHub API calls:

- Tracks API call count
- Implements exponential backoff
- Respects GitHub's rate limits
- Provides rate limit status in logs

## Performance Metrics

The script tracks the following performance metrics:

- API call duration
- Total execution time
- PR processing rate
- Memory usage
- Network latency

## Logging

The script implements structured logging with the following levels:

- DEBUG: Detailed debugging information
- INFO: General operational information
- WARN: Warning messages
- ERROR: Error messages

Log format:
```
[timestamp] LEVEL: message
```

## Security Considerations

1. **Token Security**
   - Tokens are never logged
   - Tokens are validated before use
   - Token permissions are checked

2. **Input Validation**
   - All inputs are validated
   - Special characters are handled
   - Path traversal is prevented

3. **Error Handling**
   - Sensitive information is not exposed
   - Errors are logged appropriately
   - Failures are handled gracefully

## API Endpoints

The script uses the following GitHub API endpoints:

- `GET /repos/{owner}/{repo}/pulls`
- `POST /repos/{owner}/{repo}/pulls`
- `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`
- `GET /rate_limit`
- `GET /user`

## Testing

The script includes comprehensive tests:

- Unit tests for all functions
- Integration tests for API calls
- Performance tests
- Security tests

See [TESTING.md](../TESTING.md) for more details.

## Examples

### Basic Usage
```bash
export GITHUB_TOKEN="your-token"
./github-sync.sh --source-org source-org --target-org target-org --repo repo-name
```

### Debug Mode
```bash
DEBUG=true ./github-sync.sh --source-org source-org --target-org target-org --repo repo-name
```

### Specific PR
```bash
./github-sync.sh --source-org source-org --target-org target-org --repo repo-name --pr 123
```

### Custom Config
```bash
./github-sync.sh --source-org source-org --target-org target-org --repo repo-name --config /path/to/config.yaml
``` 