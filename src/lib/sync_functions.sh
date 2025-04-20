#!/usr/bin/env bash

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
  local title
  title=$(echo "$source_pr" | jq -r '.title')
  local body
  body=$(echo "$source_pr" | jq -r '.body')
  local head
  head=$(echo "$source_pr" | jq -r '.head.ref')
  local base
  base=$(echo "$source_pr" | jq -r '.base.ref')
  local state
  state=$(echo "$source_pr" | jq -r '.state')

  # Check if PR already exists in target
  local target_prs
  target_prs=$(list_prs "$target_org" "$target_repo")
  local existing_pr
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

  if [[ -n "$pr_number" ]]; then
    sync_single_pr "$source_org" "$source_repo" "$target_org" "$target_repo" "$pr_number"
  else
    sync_all_prs "$source_org" "$source_repo" "$target_org" "$target_repo"
  fi

  log $LOG_LEVEL_INFO "Repository synchronization completed"
}

