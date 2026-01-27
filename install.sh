#!/usr/bin/env bash
set -euo pipefail

# Default install location (user-local; no sudo needed)
PREFIX_DEFAULT="${HOME}/.local/bin"
PREFIX="${PREFIX_DEFAULT}"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--prefix PATH] [all | gh aws jira gdrive slack]...

Examples:
  ./install.sh all
  ./install.sh --prefix "$HOME/.local/bin" gh jira slack
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

  python3 - "$json" "$os" "$arch" "$prefer_ext" "$name_hint" <<'PY'
import json, sys

try:
    json_input = sys.argv[1]
    data = json.loads(json_input)
    assets = data.get("assets", [])
    os_ = sys.argv[2] if len(sys.argv) > 2 else ""
    arch = sys.argv[3] if len(sys.argv) > 3 else ""
    prefer_ext = sys.argv[4] if len(sys.argv) > 4 else ""
    hint = (sys.argv[5] if len(sys.argv) > 5 else "").lower()

    candidates = []
    for a in assets:
        name = (a.get("name") or "")
        lname = name.lower()
        url = a.get("browser_download_url")
        if not url:
            continue
        os_ok = (os_ in lname) or (("mac" in lname or "darwin" in lname) and os_ == "darwin")
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

download_to() {
  local url="$1" out="$2"
  curl -fL --retry 3 --retry-delay 1 -o "$out" "$url"
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
  found="$(find "$tmpdir" -type f -name "$bin_name" -perm -u+x 2>/dev/null | head -n 1 || true)"
  if [[ -z "$found" ]]; then
    found="$(find "$tmpdir" -type f -name "$bin_name" 2>/dev/null | head -n 1 || true)"
  fi
  if [[ -z "$found" ]]; then
    echo "Could not locate ${bin_name} inside extracted archive." >&2
    rm -rf "$tmpdir"
    exit 1
  fi

  chmod +x "$found"
  install -m 0755 "$found" "${PREFIX}/${bin_name}"
  rm -rf "$tmpdir"
}

install_gh() {
  local os="$1" arch="$2"
  echo "Installing gh..."
  local url out
  # gh assets are typically .tar.gz on mac/linux
  url="$(github_asset_url "cli" "cli" "$os" "$arch" ".tar.gz" "gh")"
  out="$(mktemp -t gh.XXXXXX).tar.gz"
  download_to "$url" "$out"
  install_binary_from_archive "$out" "gh"
  rm -f "$out"
  echo "Installed: ${PREFIX}/gh"
}

install_jira() {
  local os="$1" arch="$2"
  echo "Installing jira..."
  local url out
  url="$(github_asset_url "ankitpokhrel" "jira-cli" "$os" "$arch" ".tar.gz" "jira")"
  out="$(mktemp -t jira.XXXXXX).tar.gz"
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
    install_gh "$os" "$arch"
    install_aws "$os" "$arch"
    install_jira "$os" "$arch"
    install_gdrive_cli "$os" "$arch"
    install_slack "$os" "$arch"
  else
    for a in "${args[@]}"; do
      case "$a" in
        gh)     install_gh "$os" "$arch" ;;
        aws)    install_aws "$os" "$arch" ;;
        jira)   install_jira "$os" "$arch" ;;
        gdrive) install_gdrive_cli "$os" "$arch" ;;
        slack)  install_slack "$os" "$arch" ;;
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
