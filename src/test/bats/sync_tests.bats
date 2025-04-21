#!/usr/bin/env bats

# Load the main script
# shellcheck source=../../bin/repo-sync.sh
source "$BATS_TEST_DIRNAME/../../lib/sync_functions.sh"

# shellcheck source=./test_helper.bash
source "$BATS_TEST_DIRNAME/test_helper.bash"

# debugging tests is helpful with the following snippet:

# Debug output
#    echo "DEBUG: Status: $status" >&2
#    echo "DEBUG: Output: $output" >&2
#    echo "DEBUG: Command: gh api /repos/$SOURCE_ORG/$REPO_NAME/pulls/123" >&2
    
setup() {
    setup_test_env
    mock_command gh
    mock_command git
    mock_command mkdir
    mock_command find
    mock_command rm
}

teardown() {
    cleanup_test_env
    unmock_command gh
    unmock_command git
    unmock_command mkdir
    unmock_command find
    unmock_command rm
}

@test "get_pr_info returns PR information" {
    bats_require_minimum_version 1.5.0
    # Mock gh pr view response
    mock_gh() {
        local arg1="$1"
        local arg2="$2"
        if [ "$arg1" = "api" ] && [ "$arg2" = "/repos/$SOURCE_ORG/$REPO_NAME/pulls/123" ]; then
            jq -n '{
                number: 123,
                title: "Test PR",
                body: "Test PR body",
                state: "OPEN",
                head: {
                    ref: "test-branch",
                    sha: "abc123"
                },
                base: {
                    ref: "main"
                }
            }'
        else 
            echo "ERROR: mock_gh_pr_view called with args: $*" >&2
            return 1
        fi
    }   
    
    # Mock gh command with both rate limit and pr view
    mock_command gh "mock_gh"
    
    # Call the function
    run --separate-stderr get_pr_info "$SOURCE_ORG" "$REPO_NAME" "123"
    
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.number')" = "123" ]
    [ "$(echo "$output" | jq -r '.title')" = "Test PR" ]
}

@test "list_prs returns list of PRs" {
    bats_require_minimum_version 1.5.0
    # Mock gh pr list response
    mock_gh() {
        jq -n '[
            {
                number: 123,
                title: "Test PR 1",
                state: "open"
            },
            {
                number: 124,
                title: "Test PR 2",
                state: "open"
            }
        ]'
    }
    
    # Mock gh command
    mock_command gh "mock_gh"
    
    # Call the function
    run --separate-stderr list_prs "$SOURCE_ORG" "$REPO_NAME" "open"
    
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
        
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r 'length')" = "2" ]
    [ "$(echo "$output" | jq -r '.[0].number')" = "123" ]
    [ "$(echo "$output" | jq -r '.[1].number')" = "124" ]
}

@test "create_pr creates a new PR" {
    bats_require_minimum_version 1.5.0
    # Mock gh pr create response
    mock_gh_pr_create() {
        jq -n '{
            number: 123,
            title: "Test PR",
            state: "open"
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_create"
    
    # Call the function
    run --separate-stderr create_pr "$TARGET_ORG" "$REPO_NAME" "test-branch" "main" "Test PR" "Test PR body"
        
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.number')" = "123" ]
    [ "$(echo "$output" | jq -r '.title')" = "Test PR" ]
}

@test "update_pr updates an existing PR" {
    bats_require_minimum_version 1.5.0
    # Mock gh pr edit response
    mock_gh_pr_edit() {
        jq -n '{
            number: 123,
            title: "Updated PR", 
            state: "open"
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_edit"
    
    # Call the function
    run --separate-stderr update_pr "$TARGET_ORG" "$REPO_NAME" "123" "Updated PR" "Updated PR body"
        
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    # Check the output
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.number')" = "123" ]
    [ "$(echo "$output" | jq -r '.title')" = "Updated PR" ]
}

@test "sync_single_pr creates new PR if it doesn't exist" {
    bats_require_minimum_version 1.5.0
    # Mock gh command to simulate PR doesn't exist and then create new PR
    mock_gh() {
        if [[ "$*" =~ "api /repos/$TARGET_ORG/$REPO_NAME/pulls/123" ]]; then
            # PR view returns empty since PR doesn't exist
            return 1
        elif [[ "$*" =~ "api -X PATCH" ]]; then
            jq -n '{}' # TODO: what is the correct response?
            return 0
        else
            # PR create returns new PR
            jq -n '{
                number: 123,
                title: "Test PR", 
                state: "open"
            }'
        fi
    }
    
    # Mock gh command
    mock_command gh "mock_gh"
    
    # Call the function
    run --separate-stderr sync_single_pr "$SOURCE_ORG" "$REPO_NAME" "$TARGET_ORG" "$REPO_NAME" "123"
        
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    echo "X: "$(echo "$output" | jq -r '.')"" >&2
    # Check the output
    assert_equal "$status" 0
    assert_equal "123" "$(echo "$output" | jq -r '.number')"
}

@test "sync_single_pr updates existing PR" {
    bats_require_minimum_version 1.5.0
    # Mock gh command
    mock_gh() {
        case "$*" in
            *"pr view"*)
                jq -n '{
                    number: 123,
                    title: "Existing PR",
                    state: "open"
                }'
                ;;
            *"pr edit"*)
                jq -n '{
                    number: 123,
                    title: "Updated PR",
                    state: "open"
                }'
                ;;
            *"api /repos/"*"/pulls/"*)
                jq -n '{
                    number: 123,
                    title: "Existing PR",
                    state: "open"
                }'
                ;;
            *"api /repos/"*"/pulls?state=open"*)
                jq -n '[]'
                ;;
            *"api /repos/"*"/pulls"*"-f title="*)
                jq -n '{
                    number: 123,
                    title: "Existing PR",
                    state: "open"
                }'
                ;;
            *"repo clone"*)
                # Return success for clone command
                return 0
                ;;
            *)
                echo "ERROR: Unhandled mock_gh command: $*" >&2
                return 1
                ;;
        esac
    }
    
    # Mock gh command
    mock_command gh "mock_gh"
    
    # Call the function and capture stdout and stderr separately
    run --separate-stderr sync_single_pr "$SOURCE_ORG" "$REPO_NAME" "$TARGET_ORG" "$REPO_NAME" "123"
    
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    # Check the output
    assert_equal "$status" 0
    assert_equal "123" "$(echo "$output" | jq -r '.number')"
    assert_equal "Updated PR" "$(echo "$output" | jq -r '.title')"
}

@test "sync_all_prs processes all PRs" {
    bats_require_minimum_version 1.5.0
    # Mock gh pr list to return multiple PRs
    mock_gh_pr_list() {
        jq -n '[
            {
                number: 123,
                title: "Test PR 1",
                state: "open"
            },
            {
                number: 124,
                title: "Test PR 2",
                state: "open"
            }
        ]'
    }
    
    # Mock gh pr view and edit
    mock_gh_pr_view() {
        jq -n '{
            number: '"$1"',
            title: "Test PR '"$1"'",
            state: "open"
        }'
    }
    
    mock_gh_pr_edit() {
        jq -n '{
            number: '"$1"',
            title: "Updated PR '"$1"'",
            state: "open"
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_pr_list"
    mock_command gh "mock_gh_pr_view"
    mock_command gh "mock_gh_pr_edit"
    
    # Call the function
    run --separate-stderr sync_all_prs "$SOURCE_ORG" "$REPO_NAME" "$TARGET_ORG" "$REPO_NAME" "open" 2
        
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    # Check the output
    assert_equal "$status" 0
    assert_equal "2" "$(echo "$output" | jq -r 'length')"
}

@test "update_branch updates branch to latest commit" {
    bats_require_minimum_version 1.5.0
    # Mock branch exists check
    mock_gh_branch_check() {
        jq -n '{
            name: "test-branch",
            commit: {
                sha: "abc123"
            }
        }'
    }
    
    # Mock get source commit
    mock_gh_source_commit() {
        jq -n '{
            object: {
                sha: "def456"
            }
        }'
    }
    
    # Mock update branch
    mock_gh_update_branch() {
        jq -n '{
            ref: "refs/heads/test-branch",
            object: {
                sha: "def456"
            }
        }'
    }
    
    # Mock gh command
    mock_command gh "mock_gh_branch_check"
    mock_command gh "mock_gh_source_commit"
    mock_command gh "mock_gh_update_branch"
    
    # Call the function
    run --separate-stderr update_branch "$TARGET_ORG" "$REPO_NAME" "test-branch"
        
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    # Check the output
    assert_equal "$status" 0
}

@test "update_branch fails if branch does not exist" {
    bats_require_minimum_version 1.5.0
    # Mock branch does not exist
    mock_gh_branch_check() {
        return 1
    }
    
    # Mock gh command
    mock_command gh "mock_gh_branch_check"
    
    # Call the function
    run --separate-stderr update_branch "$TARGET_ORG" "$REPO_NAME" "nonexistent-branch"
        
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    # Check the output
    assert_equal "$status" 1
}

@test "sync_single_pr_with_branch_update updates branch before syncing PR" {
    bats_require_minimum_version 1.5.0
    # Mock branch update
    mock_update_branch() {
        return 0
    }
    mock_command update_branch "mock_update_branch"
    
     # Mock gh command
    mock_gh() {
        case "$*" in
            "pr view"* | "pr"*"view"*)
                jq -n '{
                    number: 123,
                    title: "Test PR",
                    body: "Test PR body", 
                    state: "open",
                    head: {
                        ref: "test-branch",
                        sha: "abc123"
                    },
                    base: {
                        ref: "main"
                    }
                }'
                ;;
            "pr create"*)
                jq -n '{
                    number: 123,
                    title: "Test PR",
                    state: "open"
                }'
                ;;
            "api /repos/"*"/pulls/"*)
                jq -n '{
                    number: 123,
                    title: "Test PR",
                    body: "Test PR body", 
                    state: "open",
                    head: {
                        ref: "test-branch",
                        sha: "abc123"
                    },
                    base: {
                        ref: "main"
                    }
                }'
                ;;
            *)
                echo "ERROR: Unhandled mock_gh command: $*" >&2
                return 1
                ;;
        esac
    }
    
    # Mock gh command
    mock_command gh "mock_gh"
    
    # Call the function
    run --separate-stderr sync_single_pr "$SOURCE_ORG" "$REPO_NAME" "$TARGET_ORG" "$REPO_NAME" "123"
        
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    # Check the output
    assert_equal "$status" 0
}

@test "get_clone_dir returns correct path" {
    bats_require_minimum_version 1.5.0
    run --separate-stderr get_clone_dir "test-org" "test-repo"
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
    assert_equal "$status" 0
    assert_equal "$output" "${HOME}/.github-sync/clones/test-org/test-repo"
}

@test "cleanup_old_clones removes old clones" {
    bats_require_minimum_version 1.5.0
    # Mock find command to simulate old clones
    mock_find() {
        echo "/old/clone/.git"
    }
    mock_command find "mock_find"
    
    # Mock rm command
    mock_command rm "true"
    
    run --separate-stderr cleanup_old_clones
   
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    assert_equal "$status" 0
}

@test "init_clone creates new clone if none exists" {
    bats_require_minimum_version 1.5.0
    # Mock directory checks
    mock_mkdir() {
        return 0
    }
    mock_command mkdir "mock_mkdir"
    
    # Mock git commands
    mock_git() {
        case "$1" in
            "remote")
                echo "origin"
                ;;
            "remote get-url")
                echo "https://github.com/source-org/repo.git"
                ;;
        esac
    }
    mock_command git "mock_git"
    
    # Mock gh clone
    mock_gh_clone() {
        return 0
    }
    mock_command gh "mock_gh_clone"
    
    run --separate-stderr init_clone "$TARGET_ORG" "$REPO_NAME" "$SOURCE_ORG" "$SOURCE_REPO"

    # Debug output       
    echo "DEBUG: target_org: $TARGET_ORG" >&2
    echo "DEBUG: repo_name: $REPO_NAME" >&2
    echo "DEBUG: source_org: $SOURCE_ORG" >&2
    echo "DEBUG: source_repo: $SOURCE_REPO" >&2
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2

    assert_equal "$status" 0
}

@test "init_clone updates existing clone" {
    bats_require_minimum_version 1.5.0
    # Mock directory checks
    mock_mkdir() {
        return 0
    }
    mock_command mkdir "mock_mkdir"
    
    # Mock git commands for existing clone
    mock_git() {
        case "$1" in
            "remote")
                echo "origin source"
                ;;
            "remote get-url")
                echo "https://github.com/source-org/repo.git"
                ;;
            "fetch")
                return 0
                ;;
        esac
    }
    mock_command git "mock_git"
    
    echo "DEBUG: TARGET_ORG: $TARGET_ORG" >&2
    echo "DEBUG: REPO_NAME: $REPO_NAME" >&2
    echo "DEBUG: SOURCE_ORG: $SOURCE_ORG" >&2
    echo "DEBUG: SOURCE_REPO: $SOURCE_REPO" >&2
    run --separate-stderr init_clone "$TARGET_ORG" "$REPO_NAME" "$SOURCE_ORG" "$SOURCE_REPO"

    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2

    assert_equal "$status" 0
}

@test "update_branch updates branch successfully" {
    bats_require_minimum_version 1.5.0
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
    
    run --separate-stderr update_branch "$TARGET_ORG" "$REPO_NAME" "test-branch"    
   
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    assert_equal "$status" 0
}

@test "update_branch fails if branch doesn't exist" {
    bats_require_minimum_version 1.5.0
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
    
    run --separate-stderr update_branch "$TARGET_ORG" "$REPO_NAME" "nonexistent-branch"
        
    # Debug output
    echo "DEBUG: Status: $status" >&2
    echo "DEBUG: Stdout: $output" >&2
    echo "DEBUG: Stderr: $stderr" >&2
   
    assert_equal "$status" 1
} 