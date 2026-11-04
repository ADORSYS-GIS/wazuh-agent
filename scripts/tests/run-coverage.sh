#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="${1:-$REPO_ROOT/coverage}"

mkdir -p "$OUTPUT_DIR"
cd "$REPO_ROOT"

echo "==> Running Bats unit tests under kcov..."
kcov --include-pattern="$REPO_ROOT/scripts/,$REPO_ROOT/lib/,$REPO_ROOT/install.sh" --exclude-pattern="$REPO_ROOT/scripts/tests/" "$OUTPUT_DIR/kcov" bats scripts/tests/test-scripts.bats

XML_FILES=($(find "$OUTPUT_DIR/kcov" -name "sonarqube.xml"))
if [[ ${#XML_FILES[@]} -eq 0 ]]; then
    echo "Error: kcov did not generate sonarqube.xml" >&2
    exit 1
elif [[ ${#XML_FILES[@]} -gt 1 ]]; then
    echo "Error: multiple sonarqube.xml files found (${#XML_FILES[@]}): ${XML_FILES[*]}" >&2
    exit 1
fi

SONAR_XML="${XML_FILES[0]}"

cp "$SONAR_XML" "$OUTPUT_DIR/sonar-coverage.xml"
sed -i "s|path=\"$REPO_ROOT/|path=\"|g" "$OUTPUT_DIR/sonar-coverage.xml"
sed -i 's|path=".*scripts/|path="scripts/|g' "$OUTPUT_DIR/sonar-coverage.xml"
sed -i 's|path=".*lib/|path="lib/|g' "$OUTPUT_DIR/sonar-coverage.xml"

echo "==> SonarQube coverage report successfully generated at $OUTPUT_DIR/sonar-coverage.xml"
