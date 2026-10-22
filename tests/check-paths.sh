#!/usr/bin/env bash
# check-paths.sh — Static checks that setup scripts use the paths and sources
# Claude Desktop on Linux actually expects. No container needed.
# Exits 1 if any check fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SETUP_SCRIPT="${REPO_ROOT}/setup.sh"
INSTALL_SCRIPT="${REPO_ROOT}/scripts/install-in-container.sh"

PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAIL=$((FAIL + 1)); }

# expect_match <file> <regex> <description>
expect_match() {
    if grep -qE "$2" "$1"; then pass "$3"; else fail "$3"; fi
}

# expect_no_match <file> <regex> <description>
expect_no_match() {
    if grep -qE "$2" "$1"; then fail "$3"; else pass "$3"; fi
}

echo "=== Path and source checks ==="

# Claude Desktop reads its config from ~/.config/Claude (capital C)
expect_match "${SETUP_SCRIPT}" 'MCP_CONFIG_DIR="\$\{HOME\}/\.config/Claude"' \
    "setup.sh writes MCP config to ~/.config/Claude"

# Anthropic's official APT repository
expect_match "${INSTALL_SCRIPT}" 'https://downloads\.claude\.ai/claude-desktop/apt/stable' \
    "install script uses Anthropic's official APT repo"
expect_no_match "${INSTALL_SCRIPT}" '^CLAUDE_APT_[A-Z_]+=.*aaddrick' \
    "install script does not use the retired github.io APT repo"

# The GUI binary is claude-desktop; `claude` is the Claude Code CLI
expect_no_match "${INSTALL_SCRIPT}" 'command -v claude\b[^-]' \
    "install script does not probe the 'claude' CLI binary"
# distrobox-export fuzzy-matches a bare name against Name=/Exec= lines (which
# exported unrelated launchers before); export the official entry by full path.
expect_match "${SETUP_SCRIPT}" 'distrobox-export --app /usr/share/applications/com\.anthropic\.Claude\.desktop' \
    "setup.sh exports the official desktop entry by full path"

# Stale reference to the old .deb download variable
expect_no_match "${SETUP_SCRIPT}" 'CLAUDE_DEB_URL' \
    "setup.sh does not reference the removed CLAUDE_DEB_URL"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
