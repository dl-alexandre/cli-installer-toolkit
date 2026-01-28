# CLI Installer Toolkit

[![Test CLI Installations](https://github.com/dl-alexandre/cli-installer-toolkit/actions/workflows/test-installs.yml/badge.svg)](https://github.com/dl-alexandre/cli-installer-toolkit/actions/workflows/test-installs.yml)

A universal installer script for popular CLI tools. Installs to `~/.local/bin` by default — no `sudo` required (except AWS CLI on macOS).

## Supported Tools

| Tool | Description | Repo |
|------|-------------|------|
| **gh** | GitHub CLI | [cli/cli](https://github.com/cli/cli) |
| **aws** | AWS CLI v2 | [AWS Docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| **jira** | Jira CLI | [ankitpokhrel/jira-cli](https://github.com/ankitpokhrel/jira-cli) |
| **gdrive** | Google Drive CLI | [dl-alexandre/Google-Drive-CLI](https://github.com/dl-alexandre/Google-Drive-CLI) |
| **slack** | Slack CLI | [slackapi/slack-cli](https://github.com/slackapi/slack-cli) |
| **cursor** | AI Code Editor | [cursor.com](https://cursor.com) |
| **opencode** | AI IDE (Desktop App) | [anomalyco/opencode](https://github.com/anomalyco/opencode) |
| **npx** | Node.js (npm + npx) | [nodejs/node](https://github.com/nodejs/node) |

## Quick Start

```bash
# Install all CLIs (will prompt to auto-configure PATH)
curl -fsSL https://raw.githubusercontent.com/dl-alexandre/cli-installer-toolkit/main/install.sh | bash -s -- all
```

The installer will automatically offer to add `~/.local/bin` to your PATH. If you decline or the prompt doesn't appear:

```bash
# Manually add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

Or clone and run locally:

```bash
git clone https://github.com/dl-alexandre/cli-installer-toolkit.git
cd cli-installer-toolkit
./install.sh all
# Will prompt to configure PATH automatically
```

> **⚠️ Note**: Installed CLIs won't work until `~/.local/bin` is on your PATH. The installer will help you set this up.

## Usage

```bash
./install.sh [OPTIONS] [TOOLS...]

OPTIONS:
  --prefix PATH         Install location (default: ~/.local/bin)
  --non-interactive     Skip prompts, use defaults
  --skip-skills         Skip automatic skills installation for Cursor/OpenCode
  --force               Force reinstall even if already up to date
  -h, --help            Show usage

TOOLS:
  all              Install all supported tools
  gh               GitHub CLI
  aws              AWS CLI v2
  jira             Jira CLI
  gdrive           Google Drive CLI
  slack            Slack CLI
  cursor           Cursor AI Code Editor
  opencode         OpenCode AI IDE
  npx              Node.js (npm + npx)
```

### Examples

```bash
# Install all tools
./install.sh all

# Install specific tools
./install.sh gh jira slack cursor

# Custom install location
./install.sh --prefix ~/bin gh aws

# Non-interactive mode (for CI/scripts)
./install.sh --non-interactive cursor

# Skip automatic skills installation
./install.sh --skip-skills cursor

# Force reinstall even if up to date
./install.sh --force gh

# Check for updates (run again)
./install.sh gh
# Output: ✓ gh is already up to date (version: 2.42.0)
# Or: Updating gh: 2.40.0 → 2.42.0
```

## Updating Tools

The installer is **version-aware** and will automatically detect if tools need updating.

### How It Works

When you run the installer for a tool that's already installed:

1. **Checks current version** (if tool exists in `~/.local/bin`)
2. **Fetches latest version** from GitHub releases
3. **Compares versions** and shows appropriate message:
   - **New install**: `Installing gh...`
   - **Update available**: `Updating gh: 2.40.0 → 2.42.0`
   - **Already current**: `✓ gh is already up to date (version: 2.42.0)`

### Update All Tools

```bash
# Re-run with 'all' to check everything
./install.sh all

# Or update specific tools
./install.sh gh jira slack
```

### Force Reinstall

```bash
# Bypass version check and reinstall anyway
./install.sh --force gh
```

### Supported Tools

Version detection works for: `gh`, `jira`, `gdrv`, `slack`, `npx` (Node.js), `aws`

> **Note**: Tools like Cursor and OpenCode are installed via platform-specific packages and use their own update mechanisms.

## Automatic Skills Installation

When installing **Cursor** or **OpenCode**, the script automatically installs skills and plugins if:

1. `npx` is available in your PATH
2. You haven't disabled it with `--skip-skills`

### What Gets Installed

**For OpenCode:**
- [opencode-antigravity-auth](https://github.com/NoeFabris/opencode-antigravity-auth) - OAuth plugin for Google's Antigravity (access to Gemini 3 Pro and Claude Opus 4.5)
- Bundled skills from `~/.opencode/skills` (if directory exists)

**For Cursor:**
- Bundled skills from `~/.opencode/skills` (if directory exists)

### Environment Variables

- `INSTALL_SKILLS` - Set to `false` to skip automatic skills/plugin installation (default: `true`)
- `CURSOR_INTERACTIVE` - Override interactive prompts (default: `true`)
- `AUTO_PATH` - Set to `false` to skip automatic PATH configuration prompt (default: interactive prompt shown)
- `FORCE_INSTALL` - Set to `true` to force reinstall without version checks (same as `--force` flag)

### Examples

```bash
# Install OpenCode with antigravity-auth plugin and skills
./install.sh opencode

# Install Cursor with automatic skills installation
./install.sh cursor

# Install OpenCode/Cursor but skip plugins/skills
./install.sh --skip-skills opencode

# Or use environment variable
INSTALL_SKILLS=false ./install.sh cursor

# Install npx first, then OpenCode (for automatic installation)
./install.sh npx opencode
```

### Bundled Skills

This repo includes installable skills under `skills/`:

- `aws-cli`
- `jira-cli`
- `slack-cli`

Install manually with the Skills CLI:

```bash
npx skills add ./cli-installer-toolkit --list
npx skills add ./cli-installer-toolkit --skill aws-cli --skill jira-cli --skill slack-cli
```

## ⚠️ IMPORTANT: Add to PATH

**Installed CLIs will NOT work until you add `~/.local/bin` to your PATH.**

### Quick Fix (Copy & Paste)

**For zsh (macOS default, modern Linux):**
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

**For bash (older Linux/macOS):**
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

**For fish:**
```bash
fish_add_path ~/.local/bin
```

### Verify It Works

After adding to PATH, verify with:
```bash
gh --version    # or any tool you installed
```

## Special Notes

### Cursor & OpenCode Installation

Cursor and OpenCode are installed interactively by default and include **automatic plugin and skills installation** if `npx` is available.

**OpenCode includes:**
- [opencode-antigravity-auth](https://github.com/NoeFabris/opencode-antigravity-auth) plugin for Google OAuth (Gemini 3 Pro, Claude Opus 4.5)
- Bundled skills from `~/.opencode/skills`

**Linux:**
- Choose between AppImage (no sudo), .deb, or .rpm packages
- AppImage is recommended for user-local installation
- Use `--non-interactive` for automated AppImage install

**macOS:**
- Downloads a .dmg file that you drag to Applications
- Requires manual installation step
- Cannot be fully automated

**Non-interactive mode:**
```bash
./install.sh --non-interactive opencode

export CURSOR_INSTALL_METHOD=deb
./install.sh --non-interactive cursor
```

**Plugin and skills installation:**
```bash
# Install OpenCode with antigravity-auth plugin and skills (default)
./install.sh opencode

# Install Cursor with skills (default)
./install.sh cursor

# Skip plugin and skills installation
./install.sh --skip-skills opencode
```

## Platform Support

| OS | Architecture | Status |
|----|--------------|--------|
| Linux | x86_64 (amd64) | ✅ Fully supported |
| Linux | ARM64 (aarch64) | ✅ Fully supported |
| macOS | x86_64 (Intel) | ✅ Fully supported* |
| macOS | ARM64 (Apple Silicon) | ✅ Fully supported* |
| Windows | x86_64 (amd64) | ⚠️ Partial support** |

**AWS CLI on macOS requires `sudo` for the official `.pkg` installer.*

***Windows support (via Git Bash/WSL):*
- ✅ **Working:** gh (GitHub CLI), jira-cli, gdrive, slack-cli, npx
- ❌ **Not Supported:** AWS CLI (requires MSI installer with admin rights)
- ❌ **Not Supported:** "all" option (fails because AWS CLI isn't supported on Windows)

**Windows AWS CLI Installation:**

AWS CLI on Windows requires the official MSI installer which needs admin rights. For non-admin installation:

```powershell
# Download MSI
curl -o AWSCLIV2.msi https://awscli.amazonaws.com/AWSCLIV2.msi

# Extract without admin (community workaround)
msiexec /a AWSCLIV2.msi /qb TARGETDIR=%USERPROFILE%\.local
```

Alternatively, use AWS CLI in WSL (Windows Subsystem for Linux) where this script fully supports it.

## Requirements

- `curl`
- `python3`
- `tar`
- `unzip`
- `install` (typically pre-installed)

All requirements are standard on modern Linux/macOS systems.

**Windows users:** Install [Git for Windows](https://git-scm.com/download/win) to get Git Bash, which includes all required tools. Alternatively, use [WSL (Windows Subsystem for Linux)](https://docs.microsoft.com/en-us/windows/wsl/install).

## How It Works

1. Detects your OS and architecture
2. Fetches the latest release from each tool's GitHub repo
3. Downloads and extracts the appropriate binary
4. Installs to `~/.local/bin` (or custom `--prefix`)

The script uses GitHub's API to find the best matching release asset for your platform. Set `GH_TOKEN` environment variable to avoid rate limits:

```bash
export GH_TOKEN=ghp_your_token_here
./install.sh all
```

## Testing

Each tool is tested individually in CI across Ubuntu and macOS:

- Individual tool installation tests
- Multiple tool installation tests
- Full suite (`all`) installation test

See [.github/workflows/test-installs.yml](.github/workflows/test-installs.yml) for details.

## Contributing

Contributions welcome! To add a new tool:

1. Add an `install_<tool>()` function following existing patterns
2. Update the `main()` function to handle the new tool
3. Add tests in `.github/workflows/test-installs.yml`
4. Update this README

## License

MIT

## Related Projects

- [asdf](https://asdf-vm.com/) - Multi-runtime version manager
- [Homebrew](https://brew.sh/) - macOS package manager
- [mise](https://mise.jdx.dev/) - Polyglot runtime manager

This project focuses on lightweight, dependency-free installation of pre-built binaries.
