#!/usr/bin/env bats

# shellcheck source=./test_helper.bash
source "$BATS_TEST_DIRNAME/test_helper.bash"

# shellcheck source=../../lib/sync_functions.sh
source "$(dirname "$(dirname "$BATS_TEST_DIRNAME")")/lib/sync_functions.sh"

setup() {
    setup_test_env
    mock_command gh
    mock_command jq
}

teardown() {
    cleanup_test_env
    unmock_command gh
    unmock_command jq
}

@test "get_pr_info returns PR information" {
    # Mock gh pr view response
    mock_gh_pr_view() {
        echo '{
            "number": 123,
            "title": "Test PR",
            "body": "Test PR body",
            "state": "OPEN",
            "head": {
                "ref": "test-branch",
                "sha": "abc123"
            },
            "base": {
                "ref": "main"
            }
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_view"
    
    # Call the function
    run get_pr_info "$SOURCE_ORG" "$REPO_NAME" "123"
    
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.number')" = "123" ]
    [ "$(echo "$output" | jq -r '.title')" = "Test PR" ]
}

@test "list_prs returns list of PRs" {
    # Mock gh pr list response
    mock_gh_pr_list() {
        echo '[
            {
                "number": 123,
                "title": "Test PR 1",
                "state": "OPEN"
            },
            {
                "number": 124,
                "title": "Test PR 2",
                "state": "OPEN"
            }
        ]'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_list"
    
    # Call the function
    run list_prs "$SOURCE_ORG" "$REPO_NAME" "OPEN"
    
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r 'length')" = "2" ]
    [ "$(echo "$output" | jq -r '.[0].number')" = "123" ]
    [ "$(echo "$output" | jq -r '.[1].number')" = "124" ]
}

@test "create_pr creates a new PR" {
    # Mock gh pr create response
    mock_gh_pr_create() {
        echo '{
            "number": 123,
            "title": "Test PR",
            "state": "OPEN"
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_create"
    
    # Call the function
    run create_pr "$TARGET_ORG" "$REPO_NAME" "test-branch" "main" "Test PR" "Test PR body"
    
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.number')" = "123" ]
    [ "$(echo "$output" | jq -r '.title')" = "Test PR" ]
}

@test "update_pr updates an existing PR" {
    # Mock gh pr edit response
    mock_gh_pr_edit() {
        echo '{
            "number": 123,
            "title": "Updated PR",
            "state": "OPEN"
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_edit"
    
    # Call the function
    run update_pr "$TARGET_ORG" "$REPO_NAME" "123" "Updated PR" "Updated PR body"
    
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.number')" = "123" ]
    [ "$(echo "$output" | jq -r '.title')" = "Updated PR" ]
}

@test "sync_single_pr creates new PR if it doesn't exist" {
    # Mock gh pr view to return empty (PR doesn't exist)
    mock_gh_pr_view() {
        echo '{}'
    }
    
    # Mock gh pr create
    mock_gh_pr_create() {
        echo '{
            "number": 123,
            "title": "Test PR",
            "state": "OPEN"
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_view"
    mock_command gh "mock_gh_pr_create"
    
    # Call the function
    run sync_single_pr "$SOURCE_ORG" "$REPO_NAME" "$TARGET_ORG" "$REPO_NAME" "123"
    
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.number')" = "123" ]
}

@test "sync_single_pr updates existing PR" {
    # Mock gh pr view to return existing PR
    mock_gh_pr_view() {
        echo '{
            "number": 123,
            "title": "Existing PR",
            "state": "OPEN"
        }'
    }
    
    # Mock gh pr edit
    mock_gh_pr_edit() {
        echo '{
            "number": 123,
            "title": "Updated PR",
            "state": "OPEN"
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_view"
    mock_command gh "mock_gh_pr_edit"
    
    # Call the function
    run sync_single_pr "$SOURCE_ORG" "$REPO_NAME" "$TARGET_ORG" "$REPO_NAME" "123"
    
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.number')" = "123" ]
    [ "$(echo "$output" | jq -r '.title')" = "Updated PR" ]
}

@test "sync_all_prs processes all PRs" {
    # Mock gh pr list to return multiple PRs
    mock_gh_pr_list() {
        echo '[
            {
                "number": 123,
                "title": "Test PR 1",
                "state": "OPEN"
            },
            {
                "number": 124,
                "title": "Test PR 2",
                "state": "OPEN"
            }
        ]'
    }
    
    # Mock gh pr view and edit
    mock_gh_pr_view() {
        echo '{
            "number": '"$1"',
            "title": "Test PR '"$1"'",
            "state": "OPEN"
        }'
    }
    
    mock_gh_pr_edit() {
        echo '{
            "number": '"$1"',
            "title": "Updated PR '"$1"'",
            "state": "OPEN"
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_list"
    mock_command gh "mock_gh_pr_view"
    mock_command gh "mock_gh_pr_edit"
    
    # Call the function
    run sync_all_prs "$SOURCE_ORG" "$REPO_NAME" "$TARGET_ORG" "$REPO_NAME" "OPEN" 2
    
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r 'length')" = "2" ]
} 