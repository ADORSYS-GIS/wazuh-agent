#!/bin/bash
# Test script to safely test the workflow changes

set -e

echo "🧪 Testing Workflow Changes"
echo "============================"
echo ""

# 1. Check YAML syntax
echo "1️⃣ Validating YAML syntax..."
if command -v yamllint &> /dev/null; then
    yamllint .github/workflows/release.yaml && echo "✅ YAML is valid"
else
    echo "⚠️  yamllint not installed, skipping (install with: pip install yamllint)"
fi

# 2. Check for common workflow issues
echo ""
echo "2️⃣ Checking workflow structure..."

# Check if jobs exist
if grep -q "manual-tag-release:" .github/workflows/release.yaml; then
    echo "✅ manual-tag-release job found"
else
    echo "❌ manual-tag-release job NOT found"
    exit 1
fi

# Check tag trigger exists
if grep -q "tags:" .github/workflows/release.yaml; then
    echo "✅ Tag trigger configured"
else
    echo "❌ Tag trigger NOT found"
    exit 1
fi

# Check develop removed from release-please condition
if grep "release-please:" .github/workflows/release.yaml -A 5 | grep -q "refs/heads/develop"; then
    echo "❌ develop still in release-please condition"
    exit 1
else
    echo "✅ develop removed from release-please job"
fi

echo ""
echo "3️⃣ Workflow validation passed! ✅"
echo ""
echo "📋 Next steps to test on GitHub:"
echo ""
echo "Option A - Test in your fork (RECOMMENDED):"
echo "  1. Push to your fork: git push origin <branch-name>"
echo "  2. Create a test tag: git tag v0.0.0-rc.999 && git push origin v0.0.0-rc.999"
echo "  3. Check Actions tab in your fork"
echo "  4. Delete test tag: git tag -d v0.0.0-rc.999 && git push origin :refs/tags/v0.0.0-rc.999"
echo ""
echo "Option B - Test with act (local GitHub Actions runner):"
echo "  1. Install act: brew install act"
echo "  2. Run: act -l  # List workflows"
echo "  3. Run: act push -e .github/test-event.json"
echo ""
echo "Option C - Test branch protection (no tag needed):"
echo "  1. Create PR with these changes to develop"
echo "  2. Verify CI runs tests but NOT release-please"
echo "  3. Merge when ready"
echo ""
