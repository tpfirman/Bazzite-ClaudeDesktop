#!/usr/bin/env bash
# install-in-container.sh — Runs INSIDE the claude-desktop Distrobox container.
# Installs Claude Desktop (via APT repo) and the MCP filesystem server (Node.js).
# Safe to re-run for updates.
set -euo pipefail

# Community-maintained APT repository for Claude Desktop on Linux.
# Source: https://github.com/aaddrick/claude-desktop-debian
CLAUDE_APT_KEY_URL="https://pkg.claude-desktop-debian.dev/KEY.gpg"
CLAUDE_APT_REPO="deb [signed-by=/usr/share/keyrings/claude-desktop.gpg arch=amd64,arm64] https://pkg.claude-desktop-debian.dev stable main"

NODE_MIN_VERSION=18

info() { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }

# ---------------------------------------------------------------------------
# 1. Update apt
# ---------------------------------------------------------------------------
info "Updating apt package index..."
sudo apt-get update -qq

# ---------------------------------------------------------------------------
# 2. Install Electron runtime dependencies
# ---------------------------------------------------------------------------
info "Installing runtime dependencies..."
sudo apt-get install -y --no-install-recommends \
    wget \
    curl \
    ca-certificates \
    gnupg \
    git \
    libasound2t64 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxss1 \
    libxtst6 \
    xdg-utils

# ---------------------------------------------------------------------------
# 3. Add Claude Desktop APT repository (idempotent)
# ---------------------------------------------------------------------------
info "Adding Claude Desktop APT repository..."
curl -fsSL "${CLAUDE_APT_KEY_URL}" \
    | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/claude-desktop.gpg

echo "${CLAUDE_APT_REPO}" \
    | sudo tee /etc/apt/sources.list.d/claude-desktop.list > /dev/null

sudo apt-get update -qq

# ---------------------------------------------------------------------------
# 4. Install / upgrade Claude Desktop
# ---------------------------------------------------------------------------
info "Installing Claude Desktop..."
sudo apt-get install -y claude-desktop
info "Claude Desktop installed: $(command -v claude || echo 'binary not in PATH — check /opt or /usr/bin')"

# ---------------------------------------------------------------------------
# 5. Install Node.js LTS (required for MCP server)
# ---------------------------------------------------------------------------
node_needs_install=true

if command -v node &>/dev/null; then
    node_ver=$(node -e 'process.stdout.write(String(process.versions.node.split(".")[0]))')
    if (( node_ver >= NODE_MIN_VERSION )); then
        info "Node.js v${node_ver} already installed (>= ${NODE_MIN_VERSION}) — skipping."
        node_needs_install=false
    else
        warn "Node.js v${node_ver} is below minimum (${NODE_MIN_VERSION}), upgrading..."
    fi
fi

if [[ "${node_needs_install}" == "true" ]]; then
    info "Installing Node.js LTS via NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    info "Node.js $(node --version) installed."
fi

# ---------------------------------------------------------------------------
# 6. Install MCP filesystem server
# ---------------------------------------------------------------------------
info "Installing @modelcontextprotocol/server-filesystem..."
sudo npm install -g @modelcontextprotocol/server-filesystem
info "MCP filesystem server installed."
