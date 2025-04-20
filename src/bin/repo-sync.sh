#!/usr/bin/env bash

# github-sync.sh - GitHub Repository Synchronization Script
#
# This script synchronizes GitHub repositories and their pull requests between organizations.
# It handles various PR scenarios, maintains state, and provides detailed logging.

set -euo pipefail

# Enable debug mode if DEBUG environment variable is set
if [[ "${DEBUG:-}" == "true" ]]; then
  set -x
fi

# Script version
readonly VERSION="0.1.0"

# Default configuration
readonly DEFAULT_CONFIG_FILE="${HOME}/.github-sync/config.yaml"

# Current log level (default to INFO)
export LOG_LEVEL=$LOG_LEVEL_INFO

# Configuration variables
SOURCE_ORG=""
TARGET_ORG=""
REPO_NAME=""
PR_NUMBER=""
CONFIG_FILE=""
PARALLEL_JOBS=4

# Source the sync functions
# shellcheck source=src/lib/logging.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

# shellcheck source=src/lib/sync_functions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/sync_functions.sh"

# Check for required dependencies
check_dependencies() {
    log $LOG_LEVEL_DEBUG "Checking dependencies"
    
    local missing_deps=()
    
    # Check for required commands
    for cmd in bash gh jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log $LOG_LEVEL_DEBUG "Missing command: $cmd"
            missing_deps+=("$cmd")
        else
            log $LOG_LEVEL_DEBUG "Found command: $cmd"
        fi
    done

    # Check bash version
    if [[ ${BASH_VERSINFO[0]} -lt 4 || (${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -lt 4) ]]; then
        log $LOG_LEVEL_DEBUG "Bash version too old: ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
        missing_deps+=("bash>=4.4")
    else
        log $LOG_LEVEL_DEBUG "Bash version OK: ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
    fi
    
    log $LOG_LEVEL_DEBUG "All dependencies found"
}

# Validate GitHub token
validate_github_token() {
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        error "GITHUB_TOKEN environment variable is not set"
    fi

    # Test token validity
    if ! gh auth status >/dev/null 2>&1; then
        error "Invalid GitHub token or insufficient permissions"
    fi
}

# Parse command line arguments
parse_args() {
    log $LOG_LEVEL_DEBUG "Parsing arguments: $*"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --source-org)
                SOURCE_ORG="$2"
                log $LOG_LEVEL_DEBUG "Set source organization: $SOURCE_ORG"
                shift 2
                ;;
            --target-org)
                TARGET_ORG="$2"
                log $LOG_LEVEL_DEBUG "Set target organization: $TARGET_ORG"
                shift 2
                ;;
            --repo)
                REPO_NAME="$2"
                log $LOG_LEVEL_DEBUG "Set repository name: $REPO_NAME"
                shift 2
                ;;
            --pr)
                PR_NUMBER="$2"
                log $LOG_LEVEL_DEBUG "Set PR number: $PR_NUMBER"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                log $LOG_LEVEL_DEBUG "Set config file: $CONFIG_FILE"
                shift 2
                ;;
            --parallel)
                PARALLEL_JOBS="$2"
                log $LOG_LEVEL_DEBUG "Set parallel jobs: $PARALLEL_JOBS"
                shift 2
                ;;
            --help)
                log $LOG_LEVEL_DEBUG "Help requested"
                show_help
                exit 0
                ;;
            *)
                log $LOG_LEVEL_DEBUG "Unknown option: $1"
                error "Unknown option: $1"
                ;;
        esac
    done

    # Validate required arguments
    log $LOG_LEVEL_DEBUG "Validating required arguments"
    if [[ -z "$SOURCE_ORG" ]]; then
        log $LOG_LEVEL_DEBUG "Missing required argument: --source-org"
        error "Missing required argument: --source-org"
    fi
    if [[ -z "$TARGET_ORG" ]]; then
        log $LOG_LEVEL_DEBUG "Missing required argument: --target-org"
        error "Missing required argument: --target-org"
    fi
    if [[ -z "$REPO_NAME" ]]; then
        log $LOG_LEVEL_DEBUG "Missing required argument: --repo"
        error "Missing required argument: --repo"
    fi
    
    log $LOG_LEVEL_DEBUG "All required arguments present"
}

# Show help message
show_help() {
    cat << EOF
GitHub Repository Synchronization Script v$VERSION

Usage: $0 [options]

Options:
  --source-org ORG    Source organization name (required)
  --target-org ORG    Target organization name (required)
  --repo REPO         Repository name (required)
  --pr NUMBER         Specific pull request number (optional)
  --config FILE       Path to configuration file (optional)
  --parallel JOBS     Number of parallel jobs (default: 4)
  --help              Show this help message

Environment Variables:
  GITHUB_TOKEN        GitHub personal access token (required)
  DEBUG               Set to "true" to enable debug mode
  LOG_LEVEL           Set to DEBUG, INFO, WARN, or ERROR

Example:
  $0 --source-org source-org --target-org target-org --repo repo-name
EOF
}

# Load configuration from file
load_config() {
    local config_file="${CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
    
    if [[ -f "$config_file" ]]; then
        log $LOG_LEVEL_DEBUG "Loading configuration from $config_file"
        
        # Use yq to parse YAML if available, otherwise use basic parsing
        if command -v yq >/dev/null 2>&1; then
            eval "$(yq eval '. | to_entries | .[] | "export \(.key)=\"\(.value)\""' "$config_file")"
        else
            # Basic YAML parsing (limited functionality)
            while IFS=': ' read -r key value; do
                if [[ -n "$key" && -n "$value" ]]; then
                    export "${key// /_}"="${value//\"}"
                fi
            done < <(grep -v '^#' "$config_file" | grep -v '^$')
        fi
    fi
}

# Main function
main() {
  # Check dependencies
  check_dependencies

  # Parse command line arguments
  parse_args "$@"

  # Load configuration
  load_config

  # Validate GitHub token
  validate_github_token

  log $LOG_LEVEL_INFO "Starting GitHub repository synchronization (version $VERSION)"
  log $LOG_LEVEL_INFO "Source: $SOURCE_ORG/$REPO_NAME"
  log $LOG_LEVEL_INFO "Target: $TARGET_ORG/$REPO_NAME"

  if [[ -n "$PR_NUMBER" ]]; then
    log $LOG_LEVEL_INFO "Synchronizing specific PR: #$PR_NUMBER"
  fi

  # Perform synchronization
  sync_repository "$SOURCE_ORG" "$REPO_NAME" "$TARGET_ORG" "$REPO_NAME" "$PR_NUMBER"

  log $LOG_LEVEL_INFO "Synchronization completed successfully"
}

# Only run main if script is invoked directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

