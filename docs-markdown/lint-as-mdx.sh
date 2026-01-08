#!/bin/bash

# Script to temporarily convert .md files to .mdx for linting, then revert back
# This allows strict MDX validation without committing .mdx files to the repo
# Also lints the root README.md by temporarily copying it to this directory

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_README="$SCRIPT_DIR/../README.md"
LOCAL_README="$SCRIPT_DIR/README.md"

echo "🔄 Converting .md files to .mdx..."

# Copy root README.md to docs-markdown for linting
if [ -f "$ROOT_README" ]; then
    echo "📄 Copying root README.md for linting..."
    cp "$ROOT_README" "$LOCAL_README"
fi

# Find all .md files (excluding node_modules) and rename to .mdx
find . -type f -name "*.md" ! -path "*/node_modules/*" | while read file; do
    mv "$file" "${file%.md}.mdx"
done

echo "✅ Conversion complete"
echo ""
echo "🔍 Running ESLint on .mdx files..."

# Run eslint - if it fails, we still want to convert back
if npm run lint:mdx; then
    LINT_EXIT_CODE=0
    echo "✅ Linting passed"
else
    LINT_EXIT_CODE=$?
    echo "❌ Linting failed with exit code $LINT_EXIT_CODE"
fi

echo ""
echo "🔄 Reverting .mdx files back to .md..."

# Find all .mdx files (excluding node_modules) and rename back to .md
find . -type f -name "*.mdx" ! -path "*/node_modules/*" | while read file; do
    mv "$file" "${file%.mdx}.md"
done

# Remove the copied README.md (now reverted to .md from .mdx)
if [ -f "$LOCAL_README" ]; then
    echo "🧹 Cleaning up copied README.md..."
    rm "$LOCAL_README"
fi

echo "✅ Reversion complete"
echo ""

# Exit with the lint exit code
if [ $LINT_EXIT_CODE -ne 0 ]; then
    echo "❌ Linting failed. Please fix the errors above."
    exit $LINT_EXIT_CODE
else
    echo "✅ All checks passed!"
    exit 0
fi
