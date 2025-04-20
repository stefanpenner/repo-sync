#!/usr/bin/env bats

# Load the main script
# shellcheck source=../../bin/repo-sync.sh
source "$BATS_TEST_DIRNAME/../../lib/sync_functions.sh"

# shellcheck source=./test_helper.bash
source "$BATS_TEST_DIRNAME/test_helper.bash"


setup() {
    setup_test_env
    mock_command gh
    mock_command jq
    mock_command git
    mock_command mkdir
    mock_command find
    mock_command rm
}

teardown() {
    cleanup_test_env
    unmock_command gh
    unmock_command jq
    unmock_command git
    unmock_command mkdir
    unmock_command find
    unmock_command rm
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

@test "update_branch updates branch to latest commit" {
    # Mock branch exists check
    mock_gh_branch_check() {
        echo '{
            "name": "test-branch",
            "commit": {
                "sha": "abc123"
            }
        }'
    }
    
    # Mock get source commit
    mock_gh_source_commit() {
        echo '{
            "object": {
                "sha": "def456"
            }
        }'
    }
    
    # Mock update branch
    mock_gh_update_branch() {
        echo '{
            "ref": "refs/heads/test-branch",
            "object": {
                "sha": "def456"
            }
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_branch_check"
    mock_command gh "mock_gh_source_commit"
    mock_command gh "mock_gh_update_branch"
    
    # Call the function
    run update_branch "$TARGET_ORG" "$REPO_NAME" "test-branch"
    
    # Check the output
    [ "$status" -eq 0 ]
}

@test "update_branch fails if branch does not exist" {
    # Mock branch does not exist
    mock_gh_branch_check() {
        return 1
    }
    
    # Mock gh command
    mock_command gh "mock_gh_branch_check"
    
    # Call the function
    run update_branch "$TARGET_ORG" "$REPO_NAME" "nonexistent-branch"
    
    # Check the output
    [ "$status" -eq 1 ]
}

@test "sync_single_pr_with_branch_update updates branch before syncing PR" {
    # Mock PR info
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
    
    # Mock branch update
    mock_update_branch() {
        return 0
    }
    mock_command update_branch "mock_update_branch"
    
    # Mock PR create
    mock_gh_pr_create() {
        echo '{
            "number": 123,
            "title": "Test PR",
            "state": "OPEN"
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_view" "mock_gh_pr_create"
    
    # Call the function
    run sync_single_pr "$SOURCE_ORG" "$REPO_NAME" "$TARGET_ORG" "$REPO_NAME" "123"
    
    # Check the output
    [ "$status" -eq 0 ]
}

@test "get_clone_dir returns correct path" {
    run get_clone_dir "test-org" "test-repo"
    [ "$status" -eq 0 ]
    [ "$output" = "${HOME}/.github-sync/clones/test-org/test-repo" ]
}

@test "cleanup_old_clones removes old clones" {
    # Mock find command to simulate old clones
    mock_find() {
        echo "/old/clone/.git"
    }
    mock_command find "mock_find"
    
    # Mock rm command
    mock_command rm "true"
    
    run cleanup_old_clones
    [ "$status" -eq 0 ]
}

@test "init_clone creates new clone if none exists" {
    # Mock directory checks
    mock_mkdir() {
        return 0
    }
    mock_command mkdir "mock_mkdir"
    
    # Mock git commands
    mock_git_remote() {
        echo "origin"
    }
    mock_git_remote_get_url() {
        echo "https://github.com/source-org/repo.git"
    }
    mock_command git "mock_git_remote" "mock_git_remote_get_url"
    
    # Mock gh clone
    mock_gh_clone() {
        return 0
    }
    mock_command gh "mock_gh_clone"
    
    run init_clone "$TARGET_ORG" "$REPO_NAME"
    [ "$status" -eq 0 ]
}

@test "init_clone updates existing clone" {
    # Mock directory checks
    mock_mkdir() {
        return 0
    }
    mock_command mkdir "mock_mkdir"
    
    # Mock git commands for existing clone
    mock_git_remote() {
        echo "origin
source"
    }
    mock_git_remote_get_url() {
        echo "https://github.com/source-org/repo.git"
    }
    mock_git_fetch() {
        return 0
    }
    mock_command git "mock_git_remote" "mock_git_remote_get_url" "mock_git_fetch"
    
    run init_clone "$TARGET_ORG" "$REPO_NAME"
    [ "$status" -eq 0 ]
}

@test "update_branch updates branch successfully" {
    # Mock init_clone
    mock_init_clone() {
        return 0
    }
    mock_command init_clone "mock_init_clone"
    
    # Mock git commands
    mock_git_show_ref() {
        return 0
    }
    mock_git_fetch() {
        return 0
    }
    mock_git_push() {
        return 0
    }
    mock_command git "mock_git_show_ref" "mock_git_fetch" "mock_git_push"
    
    run update_branch "$TARGET_ORG" "$REPO_NAME" "test-branch"
    [ "$status" -eq 0 ]
}

@test "update_branch fails if branch doesn't exist" {
    # Mock init_clone
    mock_init_clone() {
        return 0
    }
    mock_command init_clone "mock_init_clone"
    
    # Mock git show-ref to fail (branch doesn't exist)
    mock_git_show_ref() {
        return 1
    }
    mock_command git "mock_git_show_ref"
    
    run update_branch "$TARGET_ORG" "$REPO_NAME" "nonexistent-branch"
    [ "$status" -eq 1 ]
} 