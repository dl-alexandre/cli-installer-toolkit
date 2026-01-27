#!/usr/bin/env bash
set -euo pipefail

# Default install location (user-local; no sudo needed)
PREFIX_DEFAULT="${HOME}/.local/bin"
PREFIX="${PREFIX_DEFAULT}"
INTERACTIVE="${CURSOR_INTERACTIVE:-true}"
INSTALL_SKILLS="${INSTALL_SKILLS:-true}"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--prefix PATH] [--non-interactive] [--skip-skills] [all | gh aws jira gdrive slack cursor opencode npx]...

Examples:
  ./install.sh all
  ./install.sh --prefix "$HOME/.local/bin" gh jira slack
  ./install.sh cursor
  ./install.sh --non-interactive cursor  # Use defaults, no prompts
  ./install.sh --skip-skills cursor      # Install Cursor but skip skills
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac
}

detect_arch() {
  # Normalize to common release asset naming
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    arm64|aarch64) echo "arm64" ;;
    *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
  esac
}

ensure_prefix() {
  mkdir -p "${PREFIX}"
  if ! echo ":$PATH:" | grep -q ":${PREFIX}:"; then
    echo "NOTE: ${PREFIX} is not on your PATH."
    echo "Add this to your shell rc (e.g. ~/.zshrc or ~/.bashrc):"
    echo "  export PATH=\"${PREFIX}:\$PATH\""
  fi
}

install_skills_to_editor() {
  local editor="$1"
  
  if ! $INSTALL_SKILLS; then
    echo "Skipping skills installation (INSTALL_SKILLS=false)"
    return 0
  fi
  
  if ! command -v npx >/dev/null 2>&1; then
    echo "Note: npx not found. Install npx first to add skills to $editor:"
    echo "  ./install.sh npx"
    echo "  npx skills add <path-to-skills-dir>"
    return 0
  fi
  
  # Install opencode-antigravity-auth plugin for OpenCode
  if [[ "$editor" == "OpenCode" ]]; then
    echo "Installing opencode-antigravity-auth plugin..."
    if $INTERACTIVE; then
      read -p "Install opencode-antigravity-auth plugin? [Y/n]: " install_antigravity
      if [[ ! "$install_antigravity" =~ ^[Nn]$ ]]; then
        npm install -g opencode-antigravity-auth@latest || echo "Antigravity plugin installation failed"
      fi
    else
      npm install -g opencode-antigravity-auth@latest || echo "Antigravity plugin installation failed"
    fi
  fi
  
  # Install bundled skills
  if [[ -d "${HOME}/.opencode/skills" ]]; then
    echo "Installing bundled skills to $editor..."
    if $INTERACTIVE; then
      read -p "Install skills from ${HOME}/.opencode/skills? [Y/n]: " install_skills
      if [[ ! "$install_skills" =~ ^[Nn]$ ]]; then
        npx skills add "${HOME}/.opencode/skills" --yes || echo "Skills installation skipped or failed"
      fi
    else
      npx skills add "${HOME}/.opencode/skills" --yes || echo "Skills installation skipped or failed"
    fi
  else
    echo "Note: No skills directory found at ${HOME}/.opencode/skills"
    echo "You can install skills later with: npx skills add <path-to-skills>"
  fi
}

# Fetches the best matching asset download URL from GitHub releases/latest.
# Uses python (preferred) to parse JSON (avoids jq dependency).
github_asset_url() {
  local owner="$1" repo="$2" os="$3" arch="$4" prefer_ext="$5" name_hint="$6"

  local api="https://api.github.com/repos/${owner}/${repo}/releases/latest"
  
  local json
  local auth_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  if [[ -n "$auth_token" ]]; then
    json="$(curl -fsSL -H "Authorization: Bearer ${auth_token}" -H "Accept: application/vnd.github+json" "${api}")"
  else
    json="$(curl -fsSL -H "Accept: application/vnd.github+json" "${api}")"
  fi
  
  if [[ -z "$json" ]]; then
    echo "Error: Failed to fetch release info for ${owner}/${repo}" >&2
    exit 1
  fi

  echo "$json" | python3 - "$os" "$arch" "$prefer_ext" "$name_hint" <<'PY'
import json, sys

try:
    data = json.load(sys.stdin)
    assets = data.get("assets", [])
    os_ = sys.argv[1] if len(sys.argv) > 1 else ""
    arch = sys.argv[2] if len(sys.argv) > 2 else ""
    prefer_ext = sys.argv[3] if len(sys.argv) > 3 else ""
    hint = (sys.argv[4] if len(sys.argv) > 4 else "").lower()

    candidates = []
    for a in assets:
        name = (a.get("name") or "")
        lname = name.lower()
        url = a.get("browser_download_url")
        if not url:
            continue
        os_ok = (os_ in lname) or (("mac" in lname or "darwin" in lname) and os_ == "darwin") or (("win" in lname or "windows" in lname) and os_ == "windows")
        if not os_ok:
            continue
        arch_ok = False
        if arch == "arm64":
            arch_ok = any(t in lname for t in ["arm64", "aarch64"])
        elif arch == "amd64":
            arch_ok = any(t in lname for t in ["amd64", "x86_64", "64-bit"])
        if not arch_ok:
            continue

        score = 0
        if hint and hint in lname:
            score += 10
        if prefer_ext and lname.endswith(prefer_ext):
            score += 5
        if any(lname.endswith(x) for x in [".sha256", ".sha256sum", ".sig", ".asc", ".txt"]):
            score -= 50
        candidates.append((score, name, url))

    if not candidates:
        sys.exit(2)

    candidates.sort(key=lambda x: (-x[0], x[1]))
    print(candidates[0][2])
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PY
}

node_latest_lts_version() {
  local json
  json="$(curl -fsSL https://nodejs.org/dist/index.json)"
  python3 - <<PY
import json, sys
data = json.loads("""${json}""")
for item in data:
    if item.get("lts"):
        print(item["version"])
        break
else:
    sys.exit(2)
PY
}

download_to() {
  local url="$1" out="$2"
  curl -fL --retry 3 --retry-delay 1 -o "$out" "$url"
}

get_archive_ext() {
  local os="$1"
  if [[ "$os" == "windows" ]]; then
    echo ".zip"
  else
    echo ".tar.gz"
  fi
}

install_binary_from_archive() {
  local archive="$1" bin_name="$2"

  local tmpdir
  tmpdir="$(mktemp -d)"

  case "$archive" in
    *.tar.gz|*.tgz)
      tar -xzf "$archive" -C "$tmpdir"
      ;;
    *.zip)
      need_cmd unzip
      unzip -q "$archive" -d "$tmpdir"
      ;;
    *)
      echo "Unsupported archive type: $archive" >&2
      rm -rf "$tmpdir"
      exit 1
      ;;
  esac

  local found
  if [[ "$(uname -s)" =~ ^(MINGW|MSYS|CYGWIN) ]]; then
    found="$(find "$tmpdir" -type f -name "$bin_name.exe" 2>/dev/null | head -n 1 || true)"
    if [[ -z "$found" ]]; then
      found="$(find "$tmpdir" -type f -name "$bin_name" 2>/dev/null | head -n 1 || true)"
    fi
  else
    found="$(find "$tmpdir" -type f -name "$bin_name" -perm -u+x 2>/dev/null | head -n 1 || true)"
    if [[ -z "$found" ]]; then
      found="$(find "$tmpdir" -type f -name "$bin_name" 2>/dev/null | head -n 1 || true)"
    fi
  fi
  
  if [[ -z "$found" ]]; then
    echo "Could not locate ${bin_name} inside extracted archive." >&2
    echo "Contents of tmpdir:" >&2
    find "$tmpdir" -type f 2>/dev/null | head -20 >&2 || true
    rm -rf "$tmpdir"
    exit 1
  fi

  chmod +x "$found"
  
  local target_name="$bin_name"
  if [[ "$(uname -s)" =~ ^(MINGW|MSYS|CYGWIN) ]]; then
    if [[ "$(basename "$found")" == *.exe ]]; then
      target_name="$(basename "$found")"
    else
      target_name="${bin_name}.exe"
    fi
    cp "$found" "${PREFIX}/${target_name}"
    chmod +x "${PREFIX}/${target_name}"
  else
    install -m 0755 "$found" "${PREFIX}/${target_name}"
  fi
  
  rm -rf "$tmpdir"
}

install_gh() {
  local os="$1" arch="$2"
  echo "Installing gh..."
  local url out ext
  ext="$(get_archive_ext "$os")"
  url="$(github_asset_url "cli" "cli" "$os" "$arch" "$ext" "gh")"
  out="$(mktemp -t gh.XXXXXX)${ext}"
  download_to "$url" "$out"
  install_binary_from_archive "$out" "gh"
  rm -f "$out"
  echo "Installed: ${PREFIX}/gh"
}

install_jira() {
  local os="$1" arch="$2"
  echo "Installing jira..."
  local url out ext
  ext="$(get_archive_ext "$os")"
  url="$(github_asset_url "ankitpokhrel" "jira-cli" "$os" "$arch" "$ext" "jira")"
  out="$(mktemp -t jira.XXXXXX)${ext}"
  download_to "$url" "$out"
  install_binary_from_archive "$out" "jira"
  rm -f "$out"
  echo "Installed: ${PREFIX}/jira"
}

install_gdrive_cli() {
  local os="$1" arch="$2"
  echo "Installing gdrive (dl-alexandre/Google-Drive-CLI)..."
  local url out
  # This repo's release assets are expected to contain the binary named "gdrive"
  url="$(github_asset_url "dl-alexandre" "Google-Drive-CLI" "$os" "$arch" "" "gdrive")"
  out="$(mktemp -t gdrive.XXXXXX)"

  # If it's not an archive, just install directly.
  if [[ "$url" == *.tar.gz || "$url" == *.tgz || "$url" == *.zip ]]; then
    out="${out}${url##*.}" # crude but ok
    download_to "$url" "$out"
    install_binary_from_archive "$out" "gdrive"
    rm -f "$out"
  else
    download_to "$url" "$out"
    chmod +x "$out"
    install -m 0755 "$out" "${PREFIX}/gdrive"
    rm -f "$out"
  fi

  echo "Installed: ${PREFIX}/gdrive"
}

install_slack() {
  local os="$1" arch="$2"
  echo "Installing slack..."
  local url out
  # Slack CLI releases typically ship as archives
  url="$(github_asset_url "slackapi" "slack-cli" "$os" "$arch" "" "slack")"
  out="$(mktemp -t slack.XXXXXX)"

  if [[ "$url" == *.tar.gz || "$url" == *.tgz || "$url" == *.zip ]]; then
    if [[ "$url" == *.tar.gz ]]; then out="${out}.tar.gz"; fi
    if [[ "$url" == *.tgz ]]; then out="${out}.tgz"; fi
    if [[ "$url" == *.zip ]]; then out="${out}.zip"; fi
    download_to "$url" "$out"
    install_binary_from_archive "$out" "slack"
    rm -f "$out"
  else
    download_to "$url" "$out"
    chmod +x "$out"
    install -m 0755 "$out" "${PREFIX}/slack"
    rm -f "$out"
  fi

  echo "Installed: ${PREFIX}/slack"
}

install_npx() {
  local os="$1" arch="$2"
  echo "Installing npx (Node.js LTS)..."

  local node_os node_arch ext
  case "$os" in
    darwin|linux) node_os="$os"; ext="tar.gz" ;;
    windows) node_os="win"; ext="zip" ;;
    *) echo "Unsupported OS for Node.js: $os" >&2; exit 1 ;;
  esac

  case "$arch" in
    amd64) node_arch="x64" ;;
    arm64) node_arch="arm64" ;;
    *) echo "Unsupported arch for Node.js: $arch" >&2; exit 1 ;;
  esac

  local version
  version="$(node_latest_lts_version)"

  local url
  url="https://nodejs.org/dist/${version}/node-${version}-${node_os}-${node_arch}.${ext}"

  local tmpdir archive extracted
  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/node.${ext}"
  download_to "$url" "$archive"
  
  if [[ "$ext" == "zip" ]]; then
    need_cmd unzip
    unzip -q "$archive" -d "$tmpdir"
  else
    tar -xzf "$archive" -C "$tmpdir"
  fi
  
  extracted="${tmpdir}/node-${version}-${node_os}-${node_arch}"

  local node_root
  node_root="${PREFIX%/bin}"
  mkdir -p "${node_root}/bin"

  if [[ "$os" == "windows" ]]; then
    cp "${extracted}/"*.exe "${node_root}/bin/" 2>/dev/null || true
    cp "${extracted}/node.exe" "${node_root}/bin/" 2>/dev/null || true
    if [[ -d "${extracted}/node_modules" ]]; then
      mkdir -p "${node_root}/lib"
      cp -R "${extracted}/node_modules" "${node_root}/lib/" 2>/dev/null || true
    fi
    if [[ -f "${extracted}/npm" ]]; then
      cp "${extracted}/npm" "${node_root}/bin/npm"
      cp "${extracted}/npm.cmd" "${node_root}/bin/" 2>/dev/null || true
    fi
    if [[ -f "${extracted}/npx" ]]; then
      cp "${extracted}/npx" "${node_root}/bin/npx"
      cp "${extracted}/npx.cmd" "${node_root}/bin/" 2>/dev/null || true
    fi
  else
    cp -R "${extracted}/bin" "${node_root}/"
    cp -R "${extracted}/lib" "${node_root}/"
    if [[ -d "${extracted}/include" ]]; then
      cp -R "${extracted}/include" "${node_root}/"
    fi
    if [[ -d "${extracted}/share" ]]; then
      cp -R "${extracted}/share" "${node_root}/"
    fi
  fi

  rm -rf "$tmpdir"
  echo "Installed: ${node_root}/bin/node"
  echo "Installed: ${node_root}/bin/npm"
  echo "Installed: ${node_root}/bin/npx"
}

install_aws() {
  local os="$1" arch="$2"
  echo "Installing aws (AWS CLI v2)..."

  need_cmd unzip

  if [[ "$os" == "linux" ]]; then
    local url
    if [[ "$arch" == "amd64" ]]; then
      url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    else
      url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
    fi

    local tmpdir zipfile
    tmpdir="$(mktemp -d)"
    zipfile="${tmpdir}/awscliv2.zip"
    download_to "$url" "$zipfile"
    unzip -q "$zipfile" -d "$tmpdir"

    # Install user-local (no sudo), and link aws into PREFIX
    "${tmpdir}/aws/install" -i "${HOME}/.local/aws-cli" -b "${PREFIX}" --update
    rm -rf "$tmpdir"
    echo "Installed: ${PREFIX}/aws"
    return
  fi

  # Windows: AWS provides a zip package that can be extracted
  if [[ "$os" == "windows" ]]; then
    local url
    if [[ "$arch" == "amd64" ]]; then
      url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    else
      echo "AWS CLI for Windows ARM64 not available" >&2
      return 1
    fi
    
    local tmpdir zipfile
    tmpdir="$(mktemp -d)"
    zipfile="${tmpdir}/awscliv2.zip"
    download_to "$url" "$zipfile"
    unzip -q "$zipfile" -d "$tmpdir"
    
    local install_script="${tmpdir}/aws/install"
    if [[ -f "$install_script" ]]; then
      bash "$install_script" -i "${HOME}/.local/aws-cli" -b "${PREFIX}" --update
    else
      echo "AWS install script not found, trying direct copy..." >&2
      mkdir -p "${HOME}/.local/aws-cli"
      cp -r "${tmpdir}/aws"/* "${HOME}/.local/aws-cli/" 2>/dev/null || true
      ln -sf "${HOME}/.local/aws-cli/dist/aws" "${PREFIX}/aws" 2>/dev/null || true
    fi
    
    rm -rf "$tmpdir"
    echo "Installed: ${PREFIX}/aws"
    return
  fi

  # macOS: official distribution is a .pkg; typical installation requires sudo.
  # If you do not want sudo, prefer running aws via a container or install on Linux environment.
  if [[ "$os" == "darwin" ]]; then
    local pkg_url pkgfile
    if [[ "$arch" == "amd64" ]]; then
      pkg_url="https://awscli.amazonaws.com/AWSCLIV2.pkg"
    else
      pkg_url="https://awscli.amazonaws.com/AWSCLIV2.pkg"
    fi
    pkgfile="$(mktemp -t awscli.XXXXXX).pkg"
    download_to "$pkg_url" "$pkgfile"

    echo "AWS CLI v2 macOS installer requires sudo to run the .pkg:"
    echo "  sudo installer -pkg \"$pkgfile\" -target /"
    echo "After install, 'aws' should be on PATH via the package."
    rm -f "$pkgfile"
    return
  fi
}

get_cursor_version() {
  curl -fsSL "https://cursor.com/download" | \
    grep -oE 'https://api2\.cursor\.sh/updates/download/golden/[^"]+/cursor/[0-9.]+' | \
    head -1 | \
    grep -oE '[0-9]+\.[0-9]+$' || echo "2.4"
}

install_cursor_appimage() {
  local arch="$1" version="$2"
  echo "Installing Cursor AppImage..."
  
  local cursor_arch
  if [[ "$arch" == "amd64" ]]; then
    cursor_arch="x64"
  else
    cursor_arch="$arch"
  fi
  
  local url="https://api2.cursor.sh/updates/download/golden/linux-${cursor_arch}/cursor/${version}"
  local out="${PREFIX}/cursor"
  
  echo "Downloading from: $url"
  if ! curl -fL --retry 3 --retry-delay 2 -A "cli-installer-toolkit" -o "$out" "$url"; then
    echo "Error: Failed to download Cursor AppImage" >&2
    echo "You may need to download manually from: https://cursor.com/download" >&2
    return 1
  fi
  
  chmod +x "$out"
  
  echo "Installed: ${PREFIX}/cursor (AppImage)"
}

install_cursor_deb() {
  local arch="$1" version="$2"
  echo "Installing Cursor .deb package..."
  
  local cursor_arch
  if [[ "$arch" == "amd64" ]]; then
    cursor_arch="x64"
  else
    cursor_arch="$arch"
  fi
  
  local url="https://api2.cursor.sh/updates/download/golden/linux-${cursor_arch}-deb/cursor/${version}"
  local tmpfile
  tmpfile="$(mktemp -t cursor.XXXXXX).deb"
  
  download_to "$url" "$tmpfile"
  
  echo "Running: sudo dpkg -i \"$tmpfile\""
  sudo dpkg -i "$tmpfile"
  rm -f "$tmpfile"
  
  echo "Installed: cursor (system-wide via .deb)"
}

install_cursor_rpm() {
  local arch="$1" version="$2"
  echo "Installing Cursor .rpm package..."
  
  local cursor_arch
  if [[ "$arch" == "amd64" ]]; then
    cursor_arch="x64"
  else
    cursor_arch="$arch"
  fi
  
  local url="https://api2.cursor.sh/updates/download/golden/linux-${cursor_arch}-rpm/cursor/${version}"
  local tmpfile
  tmpfile="$(mktemp -t cursor.XXXXXX).rpm"
  
  download_to "$url" "$tmpfile"
  
  echo "Running: sudo rpm -i \"$tmpfile\""
  sudo rpm -i "$tmpfile"
  rm -f "$tmpfile"
  
  echo "Installed: cursor (system-wide via .rpm)"
}

install_cursor_dmg() {
  local arch="$1" version="$2"
  echo "Downloading Cursor for macOS..."
  
  local platform
  if [[ "$arch" == "arm64" ]]; then
    platform="darwin-arm64"
  elif [[ "$arch" == "amd64" ]]; then
    platform="darwin-x64"
  else
    platform="darwin-universal"
  fi
  
  local url="https://api2.cursor.sh/updates/download/golden/${platform}/cursor/${version}"
  local tmpfile="${TMPDIR:-/tmp}/Cursor-${version}.dmg"
  
  echo "Downloading from: $url"
  if ! curl -fL --retry 3 --retry-delay 2 -A "cli-installer-toolkit" -o "$tmpfile" "$url"; then
    echo "Error: Failed to download Cursor" >&2
    echo "You may need to download manually from: https://cursor.com/download" >&2
    return 1
  fi
  
  echo ""
  echo "Downloaded to: $tmpfile"
  echo ""
  echo "To complete installation:"
  echo "  1. Open: open \"$tmpfile\""
  echo "  2. Drag Cursor.app to your Applications folder"
  echo ""
  
  if $INTERACTIVE; then
    read -p "Open DMG now? [y/N]: " open_now
    if [[ "$open_now" =~ ^[Yy]$ ]]; then
      open "$tmpfile"
    fi
  fi
}

install_cursor() {
  local os="$1" arch="$2"
  echo "Installing Cursor..."
  
  local version
  version="$(get_cursor_version)"
  echo "Latest version: $version"
  
  case "$os" in
    linux)
      if $INTERACTIVE; then
        echo ""
        echo "Cursor installation options for Linux:"
        echo "  1) AppImage (no sudo, portable, recommended)"
        echo "  2) .deb package (requires sudo, Ubuntu/Debian)"
        echo "  3) .rpm package (requires sudo, Fedora/RHEL)"
        echo ""
        read -p "Choose installation method [1-3]: " choice
        
        case "$choice" in
          1) install_cursor_appimage "$arch" "$version" ;;
          2) install_cursor_deb "$arch" "$version" ;;
          3) install_cursor_rpm "$arch" "$version" ;;
          *) echo "Invalid choice. Using AppImage."; install_cursor_appimage "$arch" "$version" ;;
        esac
      else
        local method="${CURSOR_INSTALL_METHOD:-appimage}"
        case "$method" in
          deb) install_cursor_deb "$arch" "$version" ;;
          rpm) install_cursor_rpm "$arch" "$version" ;;
          *) install_cursor_appimage "$arch" "$version" ;;
        esac
      fi
      ;;
      
    darwin)
      if $INTERACTIVE; then
        echo ""
        echo "Cursor for macOS requires manual installation:"
        echo "  1. Download will save a .dmg file"
        echo "  2. You'll need to open it and drag to Applications"
        echo ""
        read -p "Continue? [y/N]: " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          install_cursor_dmg "$arch" "$version"
        else
          echo "Cursor installation cancelled."
          return 1
        fi
      else
        echo "Cursor for macOS requires interactive installation."
        echo "Run without --non-interactive flag, or download manually from:"
        echo "  https://cursor.com/download"
        return 1
      fi
      ;;
      
    *)
      echo "Cursor installation for Windows is not supported by this script."
      echo "Please download from: https://cursor.com/download"
      return 1
      ;;
  esac
  
  install_skills_to_editor "Cursor"
}

install_opencode_deb() {
  local arch="$1"
  echo "Installing OpenCode .deb package..."
  
  local asset_name="opencode-desktop-linux-${arch}.deb"
  local url="$(github_asset_url "anomalyco" "opencode" "linux" "$arch" ".deb" "opencode-desktop")"
  local tmpfile
  tmpfile="$(mktemp -t opencode.XXXXXX).deb"
  
  download_to "$url" "$tmpfile"
  
  echo "Running: sudo dpkg -i \"$tmpfile\""
  sudo dpkg -i "$tmpfile" || true
  
  echo "Fixing dependencies..."
  sudo apt-get update -qq
  sudo apt-get install -f -y
  
  rm -f "$tmpfile"
  
  echo "Installed: opencode (system-wide via .deb)"
}

install_opencode_rpm() {
  local arch="$1"
  echo "Installing OpenCode .rpm package..."
  
  local url="$(github_asset_url "anomalyco" "opencode" "linux" "$arch" ".rpm" "opencode-desktop")"
  local tmpfile
  tmpfile="$(mktemp -t opencode.XXXXXX).rpm"
  
  download_to "$url" "$tmpfile"
  
  echo "Running: sudo rpm -i \"$tmpfile\""
  sudo rpm -i "$tmpfile"
  rm -f "$tmpfile"
  
  echo "Installed: opencode (system-wide via .rpm)"
}

install_opencode_dmg() {
  local arch="$1"
  echo "Downloading OpenCode for macOS..."
  
  local url="$(github_asset_url "anomalyco" "opencode" "darwin" "$arch" ".dmg" "opencode-desktop")"
  local tmpfile="${TMPDIR:-/tmp}/OpenCode.dmg"
  
  echo "Downloading from: $url"
  if ! download_to "$url" "$tmpfile"; then
    echo "Error: Failed to download OpenCode" >&2
    echo "You may need to download manually from: https://github.com/anomalyco/opencode/releases" >&2
    return 1
  fi
  
  echo ""
  echo "Downloaded to: $tmpfile"
  echo ""
  echo "To complete installation:"
  echo "  1. Open: open \"$tmpfile\""
  echo "  2. Drag OpenCode.app to your Applications folder"
  echo ""
  
  if $INTERACTIVE; then
    read -p "Open DMG now? [y/N]: " open_now
    if [[ "$open_now" =~ ^[Yy]$ ]]; then
      open "$tmpfile"
    fi
  fi
}

install_opencode() {
  local os="$1" arch="$2"
  echo "Installing OpenCode..."
  
  case "$os" in
    linux)
      if $INTERACTIVE; then
        echo ""
        echo "OpenCode installation options for Linux:"
        echo "  1) .deb package (requires sudo, Ubuntu/Debian, recommended)"
        echo "  2) .rpm package (requires sudo, Fedora/RHEL)"
        echo ""
        read -p "Choose installation method [1-2]: " choice
        
        case "$choice" in
          1) install_opencode_deb "$arch" ;;
          2) install_opencode_rpm "$arch" ;;
          *) echo "Invalid choice. Using .deb."; install_opencode_deb "$arch" ;;
        esac
      else
        local method="${OPENCODE_INSTALL_METHOD:-deb}"
        case "$method" in
          rpm) install_opencode_rpm "$arch" ;;
          *) install_opencode_deb "$arch" ;;
        esac
      fi
      ;;
      
    darwin)
      if $INTERACTIVE; then
        echo ""
        echo "OpenCode for macOS requires manual installation:"
        echo "  1. Download will save a .dmg file"
        echo "  2. You'll need to open it and drag to Applications"
        echo ""
        read -p "Continue? [y/N]: " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          install_opencode_dmg "$arch"
        else
          echo "OpenCode installation cancelled."
          return 1
        fi
      else
        echo "OpenCode for macOS requires interactive installation."
        echo "Run without --non-interactive flag, or download manually from:"
        echo "  https://github.com/anomalyco/opencode/releases"
        return 1
      fi
      ;;
      
    *)
      echo "OpenCode installation for Windows is not supported by this script."
      echo "Please download from: https://github.com/anomalyco/opencode/releases"
      return 1
      ;;
  esac
  
  install_skills_to_editor "OpenCode"
}

main() {
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)
        shift
        PREFIX="${1:-}"
        [[ -n "$PREFIX" ]] || { echo "--prefix requires a value" >&2; exit 1; }
        shift
        ;;
      --non-interactive)
        INTERACTIVE=false
        shift
        ;;
      --skip-skills)
        INSTALL_SKILLS=false
        shift
        ;;
      -h|--help)
        usage; exit 0
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  [[ ${#args[@]} -gt 0 ]] || { usage; exit 1; }

  need_cmd curl
  need_cmd python3
  need_cmd install
  need_cmd tar

  ensure_prefix

  local os arch
  os="$(detect_os)"
  arch="$(detect_arch)"

  local install_all=false
  for a in "${args[@]}"; do
    [[ "$a" == "all" ]] && install_all=true
  done

  if $install_all; then
    INTERACTIVE=false
    install_gh "$os" "$arch"
    install_aws "$os" "$arch"
    install_jira "$os" "$arch"
    install_gdrive_cli "$os" "$arch"
    install_slack "$os" "$arch"
    install_cursor "$os" "$arch"
    install_opencode "$os" "$arch"
    install_npx "$os" "$arch"
  else
    for a in "${args[@]}"; do
      case "$a" in
        gh)       install_gh "$os" "$arch" ;;
        aws)      install_aws "$os" "$arch" ;;
        jira)     install_jira "$os" "$arch" ;;
        gdrive)   install_gdrive_cli "$os" "$arch" ;;
        slack)    install_slack "$os" "$arch" ;;
        cursor)   install_cursor "$os" "$arch" ;;
        opencode) install_opencode "$os" "$arch" ;;
        npx)      install_npx "$os" "$arch" ;;
        *)
          echo "Unknown component: $a" >&2
          usage
          exit 1
          ;;
      esac
    done
  fi

  echo "Done."
}

main "$@"
