#!/usr/bin/env bash
#
# git.sh - Git repository operations
#
# Provides functions for git repository state checks and workflow operations.
# Used by state.sh for clean state verification and by other modules for
# git-based workflows.
#
# Usage:
#   git_in_repo                       # Check if in a git repository
#   git_get_current_branch            # Get current branch name
#   git_is_clean                      # Check if repository has uncommitted changes
#

# Check if we are in a git repository
# Returns:
#   0 if in a git repository
#   1 if not in a git repository
#
# Example:
#   if git_in_repo; then
#     echo "In a git repository"
#   else
#     echo "Not in a git repository"
#   fi
git_in_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
    return $?
}

# Get the current git branch name
# Returns:
#   Echoes the branch name (e.g., "main", "feature/foo")
#   Returns 0 on success
#   Returns 1 if not in a git repo or HEAD is detached
#
# Example:
#   branch=$(git_get_current_branch)
git_get_current_branch() {
    if ! git_in_repo; then
        return 1
    fi

    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [[ -z "$branch" ]] || [[ "$branch" == "HEAD" ]]; then
        return 1
    fi

    echo "$branch"
    return 0
}

# Check if the repository has uncommitted changes
# Uses both git diff (working tree) and git diff --cached (staged changes)
#
# Returns:
#   0 if repository is clean (no uncommitted changes)
#   1 if there are uncommitted changes (modified, added, or deleted files)
#
# Example:
#   if git_is_clean; then
#     echo "Repository is clean"
#   else
#     echo "Uncommitted changes detected"
#   fi
git_is_clean() {
    # Check for uncommitted changes in working tree
    if ! git diff --quiet HEAD 2>/dev/null; then
        return 1
    fi

    # Check for staged but uncommitted changes
    if ! git diff --cached --quiet HEAD 2>/dev/null; then
        return 1
    fi

    # Check for untracked files (files not in .gitignore)
    local untracked
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null)
    if [[ -n "$untracked" ]]; then
        return 1
    fi

    # Repository is clean
    return 0
}
