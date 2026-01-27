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
| **npx** | Node.js (npm + npx) | [nodejs/node](https://github.com/nodejs/node) |

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/dl-alexandre/cli-installer-toolkit/main/install.sh | bash -s -- all
```

Or clone and run locally:

```bash
git clone https://github.com/dl-alexandre/cli-installer-toolkit.git
cd cli-installer-toolkit
./install.sh all
```

## Usage

```bash
./install.sh [OPTIONS] [TOOLS...]

OPTIONS:
  --prefix PATH         Install location (default: ~/.local/bin)
  --non-interactive     Skip prompts, use defaults
  -h, --help            Show usage

TOOLS:
  all              Install all supported tools
  gh               GitHub CLI
  aws              AWS CLI v2
  jira             Jira CLI
  gdrive           Google Drive CLI
  slack            Slack CLI
  cursor           Cursor AI Code Editor
  npx              Node.js (npm + npx)
```

### Examples

```bash
./install.sh all

./install.sh gh jira slack cursor

./install.sh --prefix ~/bin gh aws

./install.sh --non-interactive cursor
./install.sh --prefix ~/bin gh aws npx
```

## Bundled Skills

This repo includes installable skills under `skills/`:

- `aws-cli`
- `jira-cli`
- `slack-cli`

Install with the Skills CLI:

```bash
npx skills add ./cli-installer-toolkit --list
npx skills add ./cli-installer-toolkit --skill aws-cli --skill jira-cli --skill slack-cli
```
```

### Add to PATH

After installation, add `~/.local/bin` to your PATH if not already present:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add to your shell rc file (`~/.bashrc`, `~/.zshrc`, etc.) to make it permanent:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

## Special Notes

### Cursor Installation

Cursor is installed interactively by default:

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
./install.sh --non-interactive cursor

export CURSOR_INSTALL_METHOD=deb
./install.sh --non-interactive cursor
```

## Platform Support

| OS | Architecture | Status |
|----|--------------|--------|
| Linux | x86_64 (amd64) | ✅ Fully supported |
| Linux | ARM64 (aarch64) | ✅ Fully supported |
| macOS | x86_64 (Intel) | ✅ Fully supported* |
| macOS | ARM64 (Apple Silicon) | ✅ Fully supported* |

**AWS CLI on macOS requires `sudo` for the official `.pkg` installer. All other tools install without elevated privileges.*

## Requirements

- `curl`
- `python3`
- `tar`
- `unzip`
- `install` (typically pre-installed)

All requirements are standard on modern Linux/macOS systems.

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
