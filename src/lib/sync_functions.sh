#!/usr/bin/env bash

# Guard against multiple sourcing
if [[ -n "${_SYNC_FUNCTIONS_SH_SOURCED:-}" ]]; then
  return 0
fi
_SYNC_FUNCTIONS_SH_SOURCED=1

# Source the sync functions
# shellcheck source=src/lib/logging.sh
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Global configuration
readonly GITHUB_BASE_URL=${GITHUB_BASE_URL:-"https://github.com"} 
readonly CLONE_BASE_DIR=${CLONE_BASE_DIR:-"${HOME}/.github-sync/clones"}
readonly CLONE_MAX_AGE_DAYS=${CLONE_MAX_AGE_DAYS:-7}
readonly SOURCE_REMOTE=${SOURCE_REMOTE:-"source"}
readonly MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-4}
readonly LOCK_TIMEOUT_SECONDS=${LOCK_TIMEOUT_SECONDS:-300}  # 5 minutes

# Global variables for cleanup
declare -a CLEANUP_FILES=()
declare -a CLEANUP_DIRS=()

# Setup cleanup handler
setup_cleanup() {
  trap 'cleanup_handler' EXIT INT TERM
}

# Cleanup handler
cleanup_handler() {
  local exit_code=$?
  log $LOG_LEVEL_DEBUG "Running cleanup handler"
  
  # Remove lock files
  for lock_file in "${CLEANUP_FILES[@]}"; do
    if [[ -f "$lock_file" ]]; then
      rm -f "$lock_file"
    fi
  done
  
  # Clean up temporary directories
  for dir in "${CLEANUP_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      rm -rf "$dir"
    fi
  done
  
  exit $exit_code
}

# Validate branch name
# Usage: validate_branch_name <name>
validate_branch_name() {
  local name=$1
  # Branch names can't contain spaces, ~, ^, :, ?, *, [, @, or end with .lock
  if ! [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || [[ "$name" =~ \.lock$ ]]; then
    log $LOG_LEVEL_ERROR "Invalid branch name: $name"
    return 1
  fi
  return 0
}

# List pull requests
# Usage: list_prs <org> <repo> [state]
list_prs() {
  local org=$1
  local repo=$2
  local state=${3:-"open"}
  local per_page=10 # TODO: Adding pagination support

  # Validate inputs
  if ! validate_repo_name "$org" || ! validate_repo_name "$repo"; then
    return 1
  fi

  # Validate state
  if [[ ! "$state" =~ ^(open|closed|all)$ ]]; then
    log $LOG_LEVEL_ERROR "Invalid PR state: $state"
    return 1
  fi

  # Get first page of PRs
  if ! gh api "/repos/$org/$repo/pulls?state=$state&page=1&per_page=$per_page" | jq -r '.'; then
    log $LOG_LEVEL_ERROR "Failed to fetch PRs"
    return 1
  fi

  return 0
}

# Create pull request
# Usage: create_pr <org> <repo> <title> <body> <head> <base>
create_pr() {
  local org=$1
  local repo=$2
  local title=$3
  local body=$4
  local head=$5
  local base=$6

  gh api "/repos/$org/$repo/pulls" \
    -f title="$title" \
    -f body="$body" \
    -f head="$head" \
    -f base="$base" | jq -r '.'
}

# Update pull request
# Usage: update_pr <org> <repo> <pr_number> <title> <body> <state>
update_pr() {
  local org=$1
  local repo=$2
  local pr_number=$3
  local title=$4
  local body=$5
  local state=$6

  log $LOG_LEVEL_DEBUG "Updating PR #$pr_number in $org/$repo"
  gh api -X PATCH "/repos/$org/$repo/pulls/$pr_number" \
    -f title="$title" \
    -f body="$body" \
    -f state="$state" | jq -r '.'
}

# Get clone directory for a specific repository
# Usage: get_clone_dir <org> <repo>
get_clone_dir() {
  local org=$1
  local repo=$2
  echo "${CLONE_BASE_DIR}/${org}/${repo}"
}

# Clean up old clones
cleanup_old_clones() {
  log $LOG_LEVEL_DEBUG "Cleaning up old clones"
  find "$CLONE_BASE_DIR" -type d -name ".git" -mtime +$CLONE_MAX_AGE_DAYS -exec rm -rf {} \;
  find "$CLONE_BASE_DIR" -type d -empty -delete
}

# Get pull request information
# Usage: get_pr_info <org> <repo> <pr_number>
get_pr_info() {
  local org=$1
  local repo=$2
  local pr_number=$3

  log $LOG_LEVEL_DEBUG "get_pr_info: [$org] [$repo] [$pr_number]"

  # Validate inputs
  if ! validate_repo_name "$org" || ! validate_repo_name "$repo"; then
    return 1
  fi

  log $LOG_LEVEL_DEBUG "Getting PR info for $org/$repo/$pr_number"
  
  # Get PR information
  log $LOG_LEVEL_DEBUG "Fetching PR info from GitHub API"
  if ! gh api "/repos/$org/$repo/pulls/$pr_number" | jq -r '.'; then
    log $LOG_LEVEL_ERROR "Failed to get PR information"
    return 1
  fi
}

# Initialize or update the clone
# Usage: init_clone <target_org> <target_repo> <source_org> <source_repo>
init_clone() {
  local org=$1
  local repo=$2
  local source_org=$3
  local source_repo=$4
  local clone_dir
  clone_dir=$(get_clone_dir "$org" "$repo")
  local lock_file="${clone_dir}.lock"

  # Validate inputs
  if ! validate_repo_name "$org" || ! validate_repo_name "$repo" || ! validate_repo_name "$source_org" || ! validate_repo_name "$source_repo"; then
    return 1
  fi

  log $LOG_LEVEL_DEBUG "Initializing clone for $org/$repo from $source_org/$source_repo"

  # Create clone directory if it doesn't exist
  mkdir -p "$clone_dir"
  CLEANUP_DIRS+=("$clone_dir")

  # If clone doesn't exist, create it
  if [[ ! -d "$clone_dir/.git" ]]; then
    log $LOG_LEVEL_DEBUG "Cloning target repository"
    if ! gh repo clone "$org/$repo" "$clone_dir" -- --quiet; then
      log $LOG_LEVEL_ERROR "Failed to clone target repository"
      return 1
    fi
  else
    # Update existing clone
    log $LOG_LEVEL_DEBUG "Updating existing clone"
    if ! git -C "$clone_dir" fetch origin --quiet; then
      log $LOG_LEVEL_ERROR "Failed to update clone"
      return 1
    fi
  fi

  # Add or update source remote
  local source_url="${GITHUB_BASE_URL}/${source_org}/${source_repo}.git"
  if ! git -C "$clone_dir" remote | grep -q "^$SOURCE_REMOTE$"; then
    log $LOG_LEVEL_DEBUG "Adding source remote"
    if ! git -C "$clone_dir" remote add "$SOURCE_REMOTE" "$source_url" --quiet; then
      log $LOG_LEVEL_ERROR "Failed to add source remote"
      return 1
    fi
  else
    # Update source remote URL if needed
    local current_url
    current_url=$(git -C "$clone_dir" remote get-url "$SOURCE_REMOTE")
    if [[ "$current_url" != "$source_url" ]]; then
      log $LOG_LEVEL_DEBUG "Updating source remote URL"
      if ! git -C "$clone_dir" remote set-url "$SOURCE_REMOTE" "$source_url" --quiet; then
        log $LOG_LEVEL_ERROR "Failed to update source remote URL"
        return 1
      fi
    fi
  fi

  # Fetch from source remote
  if ! git -C "$clone_dir" fetch "$SOURCE_REMOTE" --quiet; then
    log $LOG_LEVEL_ERROR "Failed to fetch from source remote"
    return 1
  fi

  return 0
}

# Check if branch exists and update it
# Usage: update_branch <org> <repo> <branch> <source_org> <source_repo>
update_branch() {
  local org=$1
  local repo=$2
  local branch=$3
  local source_org=$4
  local source_repo=$5
  local clone_dir
  clone_dir=$(get_clone_dir "$org" "$repo")

  log $LOG_LEVEL_DEBUG "Checking branch $branch in $org/$repo"

  # Initialize or update the clone
  if ! init_clone "$org" "$repo" "$source_org" "$source_repo"; then
    return 1
  fi

  # Check if branch exists in target
  if ! git -C "$clone_dir" show-ref --verify --quiet "refs/heads/$branch"; then
    log $LOG_LEVEL_INFO "Branch $branch does not exist in target repository"
    return 1
  fi

  # Check for local changes before force updating
  if ! git -C "$clone_dir" diff --quiet "origin/$branch" "$branch"; then
    log $LOG_LEVEL_WARN "Local branch $branch has uncommitted changes. These will be lost."
    if ! git -C "$clone_dir" reset --hard "origin/$branch"; then
      log $LOG_LEVEL_ERROR "Failed to reset local branch"
      return 1
    fi
  fi

  # Update target branch
  if ! git -C "$clone_dir" fetch "$SOURCE_REMOTE" "$branch:$branch" --force --quiet; then
    log $LOG_LEVEL_ERROR "Failed to update target branch"
    return 1
  fi

  # Push changes to target repository
  if ! git -C "$clone_dir" push origin "$branch" --force --quiet; then
    log $LOG_LEVEL_ERROR "Failed to push changes to target repository"
    return 1
  fi

  # log $LOG_LEVEL_INFO "Updated branch $branch in $org/$repo"
  return 0
}

# Sync a single pull request
# Usage: sync_single_pr <source_org> <source_repo> <target_org> <target_repo> <pr_number>
# outputs the sync'd target PR JSON
sync_single_pr() {
  local source_org=$1
  local source_repo=$2
  local target_org=$3
  local target_repo=$4
  local pr_number=$5
  local title body head base state target_prs existing_pr target_pr_number

  log $LOG_LEVEL_INFO "Syncing PR #$pr_number from $source_org/$source_repo to $target_org/$target_repo"

  # Get source PR information
  # TODO: maybe we will use this data later
  if ! get_pr_info "$source_org" "$source_repo" "$pr_number" > /dev/null; then
    log $LOG_LEVEL_ERROR "Failed to get source PR information"
    return 1
  fi

  # Update target branch to match source
  if ! update_branch "$target_org" "$target_repo" "$head" "$source_org" "$source_repo" > /dev/null; then
    log $LOG_LEVEL_ERROR "Failed to update branch $head in target repository"
    return 1
  fi

  # Check if PR already exists in target
  if ! target_prs=$(list_prs "$target_org" "$target_repo"); then
    log $LOG_LEVEL_ERROR "Failed to list PRs in target repository"
    return 1
  fi

  existing_pr=$(echo "$target_prs" | jq -r --arg title "$title" 'select(.title == $title)')

  if [[ -n "$existing_pr" ]]; then
    # Update existing PR
    if ! target_pr_number=$(echo "$existing_pr" | jq -r '.number') || [[ -z "$target_pr_number" ]]; then
      log $LOG_LEVEL_ERROR "Failed to extract target PR number"
      return 1
    fi

    log $LOG_LEVEL_INFO "Updating existing PR #$target_pr_number in target repository"
    if ! update_pr "$target_org" "$target_repo" "$target_pr_number" "$title" "$body" "$state"; then
      log $LOG_LEVEL_ERROR "Failed to update PR #$target_pr_number"
      return 1
    fi
  else
    # Create new PR
    # log $LOG_LEVEL_INFO "Creating new PR in target repository" >&2
    if ! create_pr "$target_org" "$target_repo" "$title" "$body" "$head" "$base"; then
      log $LOG_LEVEL_ERROR "Failed to create new PR"
      return 1
    fi
  fi

  return 0
}

# Sync all pull requests with parallel processing
# Usage: sync_all_prs <source_org> <source_repo> <target_org> <target_repo>
sync_all_prs() {
  local source_org=$1
  local source_repo=$2
  local target_org=$3
  local target_repo=$4
  local pr_numbers
  local count=0
  local total=0
  local completed=0

  log $LOG_LEVEL_INFO "Syncing all PRs from $source_org/$source_repo to $target_org/$target_repo"

  # Get all source PRs
  if ! pr_numbers=$(list_prs "$source_org" "$source_repo" | jq -r '.[].number'); then
    log $LOG_LEVEL_ERROR "Failed to get PR numbers"
    return 1
  fi

  total=$(echo "$pr_numbers" | wc -l)
  log $LOG_LEVEL_INFO "Found $total PRs to sync"

  # Process PRs in parallel with progress reporting
  for pr_number in $pr_numbers; do
    sync_single_pr "$source_org" "$source_repo" "$target_org" "$target_repo" "$pr_number"
    ((count++))
    ((completed++))

    # Show progress
    log $LOG_LEVEL_INFO "Progress: $completed/$total PRs completed"

  done

  return 0
}

# Main sync function
# Usage: sync_repository <source_org> <source_repo> <target_org> <target_repo> [pr_number]
sync_repository() {
  local source_org=$1
  local source_repo=$2
  local target_org=$3
  local target_repo=$4
  local pr_number=${5:-}

  log $LOG_LEVEL_INFO "Starting repository synchronization"
  log $LOG_LEVEL_INFO "Source: $source_org/$source_repo"
  log $LOG_LEVEL_INFO "Target: $target_org/$target_repo"

  # Clean up old clones at the start
  cleanup_old_clones

  if [[ -n "$pr_number" ]]; then
    sync_single_pr "$source_org" "$source_repo" "$target_org" "$target_repo" "$pr_number"
  else
    sync_all_prs "$source_org" "$source_repo" "$target_org" "$target_repo"
  fi

  log $LOG_LEVEL_INFO "Repository synchronization completed"
}

# Validate repository name
# Usage: validate_repo_name <name>
validate_repo_name() {
  local name=$1
  # GitHub repository names can only contain alphanumeric characters, hyphens, and underscores
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log $LOG_LEVEL_ERROR "Invalid repository name: $name"
    return 1
  fi
  return 0
}

# Setup cleanup at script start
# setup_cleanup

