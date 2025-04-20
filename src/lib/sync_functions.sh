#!/usr/bin/env bash

# Global variables for clone management
readonly CLONE_BASE_DIR="${HOME}/.github-sync/clones"
readonly CLONE_MAX_AGE_DAYS=7
readonly SOURCE_REMOTE="source"

# List pull requests
# Usage: list_prs <org> <repo> [state]
list_prs() {
  local org=$1
  local repo=$2
  local state=${3:-"open"}

  check_rate_limit
  gh api "/repos/$org/$repo/pulls?state=$state" | jq -r '.[]'
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

  check_rate_limit
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

  check_rate_limit
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

# Initialize or update the clone
# Usage: init_clone <target_org> <target_repo> <source_org> <source_repo>
init_clone() {
  local org=$1
  local repo=$2
  local source_org=$3
  local source_repo=$4
  local clone_dir
  clone_dir=$(get_clone_dir "$org" "$repo")

  # Create clone directory if it doesn't exist
  mkdir -p "$clone_dir"

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
  if ! git -C "$clone_dir" remote | grep -q "^$SOURCE_REMOTE$"; then
    log $LOG_LEVEL_DEBUG "Adding source remote"
    if ! git -C "$clone_dir" remote add "$SOURCE_REMOTE" "https://github.com/$source_org/$source_repo.git" --quiet; then
      log $LOG_LEVEL_ERROR "Failed to add source remote"
      return 1
    fi
  else
    # Update source remote URL if needed
    local current_url
    current_url=$(git -C "$clone_dir" remote get-url "$SOURCE_REMOTE")
    local expected_url="https://github.com/$source_org/$source_repo.git"
    if [[ "$current_url" != "$expected_url" ]]; then
      log $LOG_LEVEL_DEBUG "Updating source remote URL"
      if ! git -C "$clone_dir" remote set-url "$SOURCE_REMOTE" "$expected_url" --quiet; then
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

  log $LOG_LEVEL_INFO "Updated branch $branch in $org/$repo"
}

# Sync a single pull request
# Usage: sync_single_pr <source_org> <source_repo> <target_org> <target_repo> <pr_number>
sync_single_pr() {
  local source_org=$1
  local source_repo=$2
  local target_org=$3
  local target_repo=$4
  local pr_number=$5

  log $LOG_LEVEL_INFO "Syncing PR #$pr_number from $source_org/$source_repo to $target_org/$target_repo"

  # Get source PR information
  local source_pr
  source_pr=$(get_pr_info "$source_org" "$source_repo" "$pr_number")
  if [[ -z "$source_pr" ]]; then
    log $LOG_LEVEL_ERROR "Failed to get source PR information"
    return 1
  fi

  # Extract PR details
  local title body head base state
  title=$(echo "$source_pr" | jq -r '.title')
  body=$(echo "$source_pr" | jq -r '.body')
  head=$(echo "$source_pr" | jq -r '.head.ref')
  base=$(echo "$source_pr" | jq -r '.base.ref')
  state=$(echo "$source_pr" | jq -r '.state')

  # Update target branch to match source
  if ! update_branch "$target_org" "$target_repo" "$head" "$source_org" "$source_repo"; then
    log $LOG_LEVEL_WARN "Failed to update branch $head in target repository"
    return 1
  fi

  # Check if PR already exists in target
  local target_prs existing_pr
  target_prs=$(list_prs "$target_org" "$target_repo")
  existing_pr=$(echo "$target_prs" | jq -r --arg title "$title" 'select(.title == $title)')

  if [[ -n "$existing_pr" ]]; then
    # Update existing PR
    local target_pr_number
    target_pr_number=$(echo "$existing_pr" | jq -r '.number')
    log $LOG_LEVEL_INFO "Updating existing PR #$target_pr_number in target repository"
    update_pr "$target_org" "$target_repo" "$target_pr_number" "$title" "$body" "$state"
  else
    # Create new PR
    log $LOG_LEVEL_INFO "Creating new PR in target repository"
    create_pr "$target_org" "$target_repo" "$title" "$body" "$head" "$base"
  fi
}

# Sync all pull requests
# Usage: sync_all_prs <source_org> <source_repo> <target_org> <target_repo>
sync_all_prs() {
  local source_org=$1
  local source_repo=$2
  local target_org=$3
  local target_repo=$4

  log $LOG_LEVEL_INFO "Syncing all PRs from $source_org/$source_repo to $target_org/$target_repo"

  # Get all source PRs
  local source_prs
  source_prs=$(list_prs "$source_org" "$source_repo")
  if [[ -z "$source_prs" ]]; then
    log $LOG_LEVEL_INFO "No PRs found in source repository"
    return 0
  fi

  # Process PRs in parallel
  local pr_numbers
  pr_numbers=$(echo "$source_prs" | jq -r '.number')
  local count=0

  for pr_number in $pr_numbers; do
    sync_single_pr "$source_org" "$source_repo" "$target_org" "$target_repo" "$pr_number" &
    ((count++))

    # Limit parallel jobs
    if [[ $count -ge $PARALLEL_JOBS ]]; then
      wait
      count=0
    fi
  done

  # Wait for remaining jobs
  wait
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

