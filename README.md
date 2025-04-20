# GitHub Repository Synchronization Script

A well-tested, maintainable Bash script that synchronizes GitHub repositories and their pull requests between organizations.

## Features

- Synchronizes repositories between GitHub organizations
- Handles pull request synchronization
- Maintains state between runs
- Provides detailed logging
- Supports debug mode
- Comprehensive error handling
- Rate limit handling
- Parallel processing support

## Requirements

- Bash 4.4 or later
- GitHub CLI (gh) 2.0.0 or later
- jq 1.6 or later
- BATS 1.7.0 or later (for testing)
- shellcheck 0.8.0 or later (for linting)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/github-sync.git
cd github-sync
```

2. Install dependencies:
```bash
# On macOS
brew install bash gh jq bats-core shellcheck

# On Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y bash gh jq bats shellcheck
```

3. Make the script executable:
```bash
chmod +x src/bin/github-sync.sh
```

4. Set up your GitHub token:
```bash
export GITHUB_TOKEN="your-github-token"
```

## Usage

Basic usage:
```bash
./src/bin/github-sync.sh --source-org source-org --target-org target-org --repo repo-name
```

Synchronize specific pull requests:
```bash
./src/bin/github-sync.sh --source-org source-org --target-org target-org --repo repo-name --pr 123
```

Enable debug mode:
```bash
DEBUG=true ./src/bin/github-sync.sh --source-org source-org --target-org target-org --repo repo-name
```

## Configuration

The script can be configured using environment variables or a configuration file.

### Environment Variables

- `GITHUB_TOKEN`: Your GitHub personal access token
- `DEBUG`: Set to "true" to enable debug mode
- `LOG_LEVEL`: Set to "DEBUG", "INFO", "WARN", or "ERROR"

### Configuration File

Create a configuration file at `~/.github-sync/config.yaml`:

```yaml
github_token: your-github-token
log_level: INFO
default_source_org: your-source-org
default_target_org: your-target-org
```

## Testing

Run the test suite:
```bash
bats src/test/bats/
```

Run specific tests:
```bash
bats src/test/bats/basic_tests.bats
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Implement your changes
5. Run the test suite
6. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure the script is executable: `chmod +x src/bin/github-sync.sh`
   - Check GitHub token permissions

2. **GitHub API Rate Limits**
   - The script includes rate limit handling
   - Consider using a GitHub Enterprise token for higher limits

3. **Dependency Issues**
   - Ensure all required dependencies are installed
   - Check version requirements

### Getting Help

- Check the [documentation](docs/)
- Open an issue on GitHub
- Contact the maintainers

## Security

- Never commit your GitHub token
- Use environment variables or secure credential storage
- Regularly rotate your GitHub token
- Follow the principle of least privilege

## Performance

The script is optimized for:
- Handling repositories with 1000+ PRs
- Processing PRs at a rate of at least 10 per minute
- Efficient API usage
- Parallel processing where appropriate 