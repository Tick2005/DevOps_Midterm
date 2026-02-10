#!/bin/bash

# Script to delete Git branches (both local and remote)
# Cách sử dụng: ./delete-branch.sh <tên-nhánh>
# 
# Lưu ý: Trước khi chạy lần đầu, cần cấp quyền thực thi:
# chmod +x delete-branch.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if branch name is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Branch name is required${NC}"
    echo "Usage: $0 <branch-name>"
    echo "Example: $0 copilot/vscode-mlgl0w5b-8mwx"
    exit 1
fi

BRANCH_NAME=$1
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Validate branch name format (only allow alphanumeric, -, _, /)
if ! [[ "$BRANCH_NAME" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
    echo -e "${RED}Error: Invalid branch name format${NC}"
    echo "Branch name should only contain letters, numbers, hyphens, underscores, and slashes"
    exit 1
fi

# Check if we're on the branch we're trying to delete
if [ "$CURRENT_BRANCH" == "$BRANCH_NAME" ]; then
    echo -e "${RED}Error: Cannot delete the current branch${NC}"
    echo "Please switch to another branch first (e.g., git checkout main)"
    exit 1
fi

# Check if branch exists locally
if git show-ref --verify --quiet refs/heads/"$BRANCH_NAME"; then
    echo -e "${YELLOW}Deleting local branch: $BRANCH_NAME${NC}"
    # Try safe delete first, fallback to force delete if needed
    if git branch -d "$BRANCH_NAME" 2>/dev/null; then
        echo -e "${GREEN}✓ Local branch deleted successfully${NC}"
    else
        echo -e "${YELLOW}Branch has unmerged changes. Force deleting...${NC}"
        git branch -D "$BRANCH_NAME"
        echo -e "${GREEN}✓ Local branch force deleted successfully${NC}"
    fi
else
    echo -e "${YELLOW}Local branch not found, skipping...${NC}"
fi

# Check if branch exists on remote
if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    echo -e "${YELLOW}Deleting remote branch: $BRANCH_NAME${NC}"
    git push origin --delete "$BRANCH_NAME"
    echo -e "${GREEN}✓ Remote branch deleted successfully${NC}"
else
    echo -e "${YELLOW}Remote branch not found, skipping...${NC}"
fi

echo -e "${GREEN}Branch deletion completed!${NC}"
