#!/bin/bash
set -e

ARTIFACT="artifact.txt"

# 1. Force a refresh of remote tracking
git fetch origin --quiet

# 2. Function to check if a branch exists on remote
check_branch() {
    if ! git rev-parse --verify "origin/$1" >/dev/null 2>&1; then
        echo "❌ Error: Branch 'origin/$1' not found on GitHub."
        echo "Make sure you pushed it: git push origin $1"
        exit 1
    fi
}

echo "🔍 Locating branches..."
check_branch "alpha"
check_branch "beta"
check_branch "gamma"
check_branch "main"

# Helper: Find commit where artifact was ADDED
intro_commit () {
  git log "origin/$1" --diff-filter=A --pretty=format:%H -- "$ARTIFACT" | tail -n 1
}

echo "📡 Analyzing artifact movement..."

# We use the remote refs (origin/...) for everything
ALPHA_C=$(intro_commit "alpha")
BETA_C=$(intro_commit "beta")
GAMMA_C=$(intro_commit "gamma")
MAIN_C=$(intro_commit "main")

# Verify the file exists in the history of all branches
for c in "$ALPHA_C" "$BETA_C" "$GAMMA_C" "$MAIN_C"; do
  if [ -z "$c" ]; then
    echo "❌ Artifact trace lost. The file must exist in alpha, beta, gamma, and main."
    exit 1
  fi
done

echo "🧪 Verifying Patch Integrity..."

# Get the file content from those specific commits
P_ALPHA=$(git show "$ALPHA_C":"$ARTIFACT")
P_BETA=$(git show "$BETA_C":"$ARTIFACT")
P_GAMMA=$(git show "$GAMMA_C":"$ARTIFACT")
P_MAIN=$(git show "$MAIN_C":"$ARTIFACT")

if [ "$P_ALPHA" != "$P_BETA" ] || [ "$P_BETA" != "$P_GAMMA" ] || [ "$P_GAMMA" != "$P_MAIN" ]; then
    echo "❌ Validation failed: The artifact was modified or copied instead of cherry-picked."
    exit 1
fi

echo "🛡️ Checking for illegal merges..."
# Ensure the artifact didn't enter main via a merge
if git log origin/main --merges --format=%H -- "$ARTIFACT" | grep -q .; then
  echo "❌ Violation: Merge commit detected (not allowed)."
  exit 1
fi

echo "✅LEVEL 5 PASSED"
