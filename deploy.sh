#!/usr/bin/env bash
# ===================================================
# Blog Deploy Script
# Builds Astro site & pushes dist/ to GitHub Pages
# Target: c92d58/blog → blog branch (GitHub Pages)
# ===================================================
set -euo pipefail

BLOG_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_EMAIL="x@wahsun.org"
GIT_NAME="c92d58"
BRANCH_SOURCE="master"
BRANCH_DEPLOY="blog"

cd "$BLOG_DIR"

echo "🔍 Checking git status..."
if [ -n "$(git status --porcelain)" ]; then
  echo "⚠️  You have uncommitted changes. Commit or stash them first."
  exit 1
fi

echo "🏗️  Building site..."
pnpm build

echo "🚀 Deploying to GitHub Pages ($BRANCH_DEPLOY branch)..."
git add -f dist/
git commit -m "chore: deploy $(date '+%Y-%m-%d %H:%M')" || echo "Nothing new to commit"

DEPLOY_HASH=$(git rev-parse --short HEAD)

# Use subtree split to extract dist/ contents into the deploy branch
git subtree split --prefix dist -b "$BRANCH_DEPLOY" --force

# Force push (we want the deploy branch to be exactly dist/ contents)
git push origin "$BRANCH_DEPLOY" --force

# Clean up local deploy branch
git branch -D "$BRANCH_DEPLOY"

# Also push the source branch
git push origin "$BRANCH_SOURCE"

echo ""
echo "✅ Deploy complete!"
echo "   Source:  origin/$BRANCH_SOURCE (@ $DEPLOY_HASH)"
echo "   Deploy:  origin/$BRANCH_DEPLOY"
echo "   Site:    https://c92d58.github.io/blog/"
