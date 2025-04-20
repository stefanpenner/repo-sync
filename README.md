# GitHub PR Sync

**note: this is more of an exercise in "vibe" coding then anything else, don't judge**

A Bash script that synchronizes pull requests between GitHub organizations. This tool helps maintain consistency across repository mirrors by automatically syncing PRs, their states, and associated branches.

## Features

- Syncs PRs between GitHub repos (even between repos in different orgs)
- Maintains PR states, titles, and descriptions
- Updates associated branches
- Handles rate limiting
- Supports parallel processing
- Includes comprehensive test suite

## Requirements

- Bash 4.4+
- GitHub CLI (`gh`) 2.0.0+
- `jq` 1.6+

## Installation

1. Clone and setup:
```bash
git clone <repo-url>
cd repo-clone
chmod +x src/bin/repo-sync.sh
```

2. Set your GitHub token:
```bash
export GITHUB_TOKEN="your-github-token"
```

## Usage

Basic sync:
```bash
./src/bin/repo-sync.sh --source-org source-org --target-org target-org --repo repo-name
```

Sync specific PR:
```bash
./src/bin/repo-sync.sh --source-org source-org --target-org target-org --repo repo-name --pr 123
```

Debug mode:
```bash
DEBUG=true ./src/bin/repo-sync.sh --source-org source-org --target-org target-org --repo repo-name
```

## Configuration

Configure via environment variables or `~/.github-sync/config.yaml`:

```yaml
github_token: your-github-token
log_level: INFO
default_source_org: your-source-org
default_target_org: your-target-org
```

## Development

Run tests:
```bash
bats src/test/bats/
```

## License

MIT 