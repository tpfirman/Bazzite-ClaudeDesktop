# Claude Desktop on Bazzite Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Lint](https://github.com/tpfirman/Bazzite-ClaudeDesktop/actions/workflows/ci.yml/badge.svg)](https://github.com/tpfirman/Bazzite-ClaudeDesktop/actions/workflows/ci.yml)

Installs [Claude Desktop](https://claude.ai/download) on [Bazzite](https://bazzite.gg/) (an immutable Fedora-based gaming/desktop OS) using a [Distrobox](https://distrobox.it/) container. Because Bazzite's host filesystem is read-only, the app runs inside an Ubuntu 24.04 container and is exported to the host desktop via `distrobox-export`.

**Features**
- MCP filesystem server pre-configured to browse repos at `/mnt/git` (configurable via `.env`)
- Multiple directories supported — expose as many host paths as you need to Claude Desktop
- Full internet + local LAN access (container shares host network namespace)
- Wayland support out of the box (`ELECTRON_OZONE_PLATFORM_HINT=auto`)
- Idempotent setup — re-run `./setup.sh` to update

---

## Requirements

- Bazzite (or any Fedora Silverblue/Kinoite-based OS with Distrobox pre-installed)
- `/mnt/git` (or whichever directories you configure) — mounted and accessible before running setup

---

## Setup

```bash
git clone https://github.com/tpfirman/Bazzite-ClaudeDesktop.git
cd Bazzite-ClaudeDesktop

# Optional: configure directories and container settings
cp example.env .env
$EDITOR .env

./setup.sh
```

That's it. The script will:

1. Create an Ubuntu 24.04 Distrobox container named `claude-desktop` with your configured directories mounted
2. Install Claude Desktop via [Anthropic's official APT repository](https://code.claude.com/docs/en/desktop-linux) and its dependencies
3. Install Node.js LTS and the MCP filesystem server (`@modelcontextprotocol/server-filesystem`)
4. Write `~/.config/Claude/claude_desktop_config.json` — creating it on first run, updating only the `filesystem` entry on subsequent runs
5. Export the app to your host desktop (app grid + `.desktop` launcher)
6. Patch the launcher for Wayland
7. Install the git pre-commit hook (shell + JSON linting)

### Launching

From your app grid, or from a terminal:

```bash
distrobox enter --name claude-desktop -- claude-desktop
```

---

## Updating Claude Desktop

Re-run the setup script — it will re-download and reinstall the latest `.deb` without recreating the container:

```bash
./setup.sh
```

---

## Configuration (`.env`)

Copy `example.env` to `.env` and edit before running `setup.sh`. `.env` is excluded from git.

| Variable | Default | Description |
|---|---|---|
| `CONTAINER_NAME` | `claude-desktop` | Distrobox container name |
| `CONTAINER_IMAGE` | `ubuntu:24.04` | Container base image |
| `MOUNT_DIRS` | `/mnt/git` | Space-separated list of host paths to mount and expose to Claude |

**Example `.env` with multiple directories:**

```bash
CONTAINER_NAME="claude-desktop"
CONTAINER_IMAGE="ubuntu:24.04"
MOUNT_DIRS="/mnt/git /home/user/projects /mnt/data"
```

> **Note:** Directories are mounted at container creation time. If you add new directories after the container already exists, recreate it:
> ```bash
> distrobox rm claude-desktop && ./setup.sh
> ```

---

## MCP Configuration

The live config lives at `~/.config/Claude/claude_desktop_config.json` — outside the repo, so it can never be accidentally committed.

### How setup.sh manages the config

`setup.sh` uses a **surgical merge** strategy on every run:

- It **always updates** the `filesystem` MCP server entry with the paths from `MOUNT_DIRS` in `.env`
- It **never touches** any other MCP server you have configured — API keys, custom args, and additional servers are preserved across every re-run

The starting point for the config is resolved in this order:

| Priority | Source | When used |
|---|---|---|
| 1 | Existing installed config | Re-runs — your customisations are the base |
| 2 | `config/claude_desktop_config.json` (git-ignored) | First install with a local template |
| 3 | Empty `{}` | Fresh install, no template |

### Adding your own MCP servers

Edit `~/.config/Claude/claude_desktop_config.json` directly and restart Claude Desktop. `setup.sh` will leave your additions untouched on future runs:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/mnt/git"]
    },
    "my-server": {
      "command": "npx",
      "args": ["-y", "my-mcp-package"],
      "env": {
        "API_KEY": "sk-..."
      }
    }
  }
}
```

### Pre-seeding servers for a new install

If you want additional MCP servers to be present on a fresh install (e.g. when setting up a new machine), copy the example template and add your servers there. It is git-ignored so credentials stay local:

```bash
cp config/claude_desktop_config.example.json config/claude_desktop_config.json
$EDITOR config/claude_desktop_config.json
```

On a fresh install, `setup.sh` will use this file as the base and inject the `filesystem` entry on top. On subsequent runs the installed config takes precedence and the local template is ignored.

### Updating `MOUNT_DIRS`

Just edit `.env` and re-run `setup.sh` — the `filesystem` entry is always updated. No need to delete the config first.

---

## Troubleshooting

### "Git is required for local sessions" when opening a local project

Git was not installed in the container. Re-run setup to add it:

```bash
./setup.sh
```

Or install it directly without recreating the container:

```bash
distrobox enter --name claude-desktop -- sudo apt-get install -y git
```

Then restart Claude Desktop.

---

### `distrobox: command not found`

Distrobox ships with Bazzite but may not be in `PATH` for all shells. Try:

```bash
ujust setup-distrobox   # Bazzite helper
# or
/usr/bin/distrobox list
```

---

### `/mnt/git` not accessible inside the container

The volume is mounted at container creation time. If `/mnt/git` wasn't available when you ran `./setup.sh`, recreate the container:

```bash
distrobox rm claude-desktop
./setup.sh
```

Verify the mount is visible inside the container:

```bash
distrobox enter --name claude-desktop -- ls /mnt/git
```

---

### Claude Desktop exits silently with no window

Electron dependency missing — launch from a terminal to see Electron's output, and check for missing libraries:

```bash
distrobox enter --name claude-desktop -- claude-desktop
distrobox enter --name claude-desktop -- bash -c 'ldd /usr/lib/claude-desktop/claude-desktop | grep "not found"'
```

A common cause is a missing shared library (e.g. `libasound.so.2: cannot open shared object file`). Re-running `./setup.sh` installs the full dependency list including `libasound2t64`. If you created the container before this fix was added, the quickest path is to re-run the install script directly:

```bash
distrobox enter --name claude-desktop -- sudo apt-get install -y libasound2t64
```

> **Note:** The `claude` command inside the container is the Claude Code CLI — the correct binary for Claude Desktop is `claude-desktop`.

---

### Claude Desktop won't launch / blank window

**Wayland issue** — check that `ELECTRON_OZONE_PLATFORM_HINT=auto` is in the `.desktop` file:

```bash
grep ELECTRON ~/.local/share/applications/claude-desktop-com.anthropic.Claude.desktop
```

If it's missing, re-run `./setup.sh` to re-apply the patch, or force X11 as a workaround:

```bash
distrobox enter --name claude-desktop -- env DISPLAY=:0 claude-desktop
```

---

### MCP filesystem server not connecting

In Claude Desktop, go to **Settings → Developer → MCP Servers** and check the `filesystem` status.

Common causes:

| Symptom | Fix |
|---|---|
| `npx: command not found` | Run `./setup.sh` again — Node.js may not have installed correctly |
| `/mnt/git` permission denied | Check that your user owns the mount point |
| Server listed but shows error | Restart Claude Desktop; check `~/.config/Claude/claude_desktop_config.json` for syntax errors |

To test the MCP server manually inside the container:

```bash
distrobox enter --name claude-desktop -- npx -y @modelcontextprotocol/server-filesystem /mnt/git
```

---

### App not showing in app grid after export

```bash
distrobox enter --name claude-desktop -- distrobox-export --app /usr/share/applications/com.anthropic.Claude.desktop
```

Then refresh your app grid (log out/in or `killall gnome-shell` on GNOME).

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow.

This project is heavily AI-assisted ("vibe coded"), but every change is human-reviewed and tested on real hardware before merging. All pull requests require human review and approval.

---

## Repo Structure

```
setup.sh                                    # Run this on Bazzite to install everything
example.env                                 # Config template — copy to .env and edit
.env                                        # Your local config (git-ignored)
LICENSE                                     # MIT license
CONTRIBUTING.md                             # Contribution guidelines
config/claude_desktop_config.example.json   # MCP config reference template
config/claude_desktop_config.json           # Local MCP config override (git-ignored)
scripts/install-in-container.sh             # Runs inside the container (called by setup.sh)
tests/lint.sh                               # shellcheck + JSON validation
hooks/pre-commit                            # Git pre-commit hook (runs lint.sh)
hooks/install-hooks.sh                      # Wires hooks/ into .git/hooks/
.github/workflows/ci.yml                    # CI: lint on push/PR to main
.github/ISSUE_TEMPLATE/                     # GitHub issue templates
```
