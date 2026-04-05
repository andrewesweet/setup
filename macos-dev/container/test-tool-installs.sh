#!/usr/bin/env bash
set -uo pipefail

# test-tool-installs.sh — verify all dotfiles tools install and run on macOS
#
# Usage:
#   bash test-tool-installs.sh              # test all tools
#   bash test-tool-installs.sh --install    # install missing tools first, then test
#   bash test-tool-installs.sh --diagnose   # reinstall + verbose diagnostics for failures
#
# Output: pass/fail for each tool with the method used to install it.
# Tools that fail the no-op run are likely blocked by binary signature policy.

INSTALL=false
DIAGNOSE=false
case "${1:-}" in
  --install)  INSTALL=true ;;
  --diagnose) INSTALL=true; DIAGNOSE=true ;;
esac

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

PASS=0
FAIL=0
SKIP=0

results=()
diagnostics=()

check_tool() {
  local name="$1"
  local install_method="$2"
  local test_cmd="$3"
  local brew_name="${4:-$name}"

  # Install if requested and not present
  if $INSTALL && ! command -v "$name" &>/dev/null; then
    case "$install_method" in
      brew)
        echo "Installing $brew_name via brew..."
        brew install "$brew_name" 2>/dev/null
        ;;
      cask)
        echo "Installing $brew_name via brew cask..."
        brew install --cask "$brew_name" 2>/dev/null
        ;;
      uv-tool)
        echo "Installing $name via uv tool..."
        uv tool install "$brew_name" 2>/dev/null
        ;;
      bun-global)
        echo "Installing $name via bun global..."
        bun install -g "$brew_name" 2>/dev/null
        ;;
      npm-global)
        echo "Installing $name via npm global..."
        npm install -g "$brew_name" 2>/dev/null
        ;;
      mise)
        echo "Installing $name via mise..."
        mise use -g "$brew_name" 2>/dev/null
        ;;
      skip)
        ;;
    esac
  fi

  # Test
  if ! command -v "$name" &>/dev/null; then
    if $DIAGNOSE; then
      diagnostics+=("")
      diagnostics+=("── SKIP: $name ──────────────────────────────")
      diagnostics+=("  Binary '$name' not found on PATH")
      diagnostics+=("  PATH: $PATH")
      # Check if brew knows about it
      local brew_info
      if brew_info=$(brew info "$brew_name" 2>&1); then
        diagnostics+=("  brew info $brew_name:")
        diagnostics+=("$(echo "$brew_info" | head -5 | sed 's/^/    /')")
      fi
      # Check brew prefix for actual binary names
      local prefix
      if prefix=$(brew --prefix "$brew_name" 2>/dev/null) && [[ -d "$prefix" ]]; then
        diagnostics+=("  brew prefix: $prefix")
        if [[ -d "$prefix/bin" ]]; then
          diagnostics+=("  binaries in $prefix/bin/:")
          diagnostics+=("$(ls -la "$prefix/bin/" 2>/dev/null | sed 's/^/    /')")
        else
          diagnostics+=("  no bin/ directory in prefix")
        fi
        # Check if linked
        local linked
        linked=$(brew list "$brew_name" 2>/dev/null | head -10)
        if [[ -n "$linked" ]]; then
          diagnostics+=("  brew list $brew_name (first 10 files):")
          diagnostics+=("$(echo "$linked" | head -10 | sed 's/^/    /')")
        fi
      fi
    fi
    results+=("$(printf "${YELLOW}SKIP${RESET}  %-20s  not installed (%s)" "$name" "$install_method")")
    ((SKIP++))
    return
  fi

  local binary_path version_output
  binary_path=$(command -v "$name")

  if version_output=$(eval "$test_cmd" 2>&1); then
    version_output=$(echo "$version_output" | head -1 | sed 's/^[[:space:]]*//')
    results+=("$(printf "${GREEN}PASS${RESET}  %-20s  %-14s  %s" "$name" "$install_method" "$version_output")")
    ((PASS++))
  else
    if $DIAGNOSE; then
      diagnostics+=("")
      diagnostics+=("── FAIL: $name ──────────────────────────────")
      diagnostics+=("  binary path: $binary_path")
      diagnostics+=("  file type:   $(file "$binary_path" 2>&1)")
      diagnostics+=("  code sign:   $(codesign -dv "$binary_path" 2>&1 || true)")
      diagnostics+=("  test cmd:    $test_cmd")
      diagnostics+=("  stderr:")
      diagnostics+=("$(eval "$test_cmd" 2>&1 | sed 's/^/    /')")
      # Check if it's a Homebrew bottle or source build
      local install_receipt
      install_receipt=$(brew info --json=v2 "$brew_name" 2>/dev/null \
        | jq -r '.formulae[0].installed[0].built_as_bottle // "unknown"' 2>/dev/null)
      diagnostics+=("  installed as bottle: $install_receipt")
    fi
    results+=("$(printf "${RED}FAIL${RESET}  %-20s  %-14s  (binary may be blocked)" "$name" "$install_method")")
    ((FAIL++))
  fi
}

echo "============================================"
echo "  Dotfiles Tool Verification"
echo "  $(date)"
echo "  Mode: $(if $INSTALL; then echo 'install + test'; else echo 'test only'; fi)"
echo "============================================"
echo ""

# ── Shell ────────────────────────────────────────────────────────────────────
echo "── Shell ──"
check_tool "bash"              "brew"       "bash --version"
# bash-completion is a shell script, no binary to test
check_tool "starship"          "brew"       "starship --version"

# ── Git core ─────────────────────────────────────────────────────────────────
echo "── Git core ──"
check_tool "git"               "brew"       "git --version"
check_tool "delta"             "brew"       "delta --version"          "git-delta"
check_tool "difft"             "brew"       "difft --version"          "difftastic"
check_tool "lazygit"           "brew"       "lazygit --version"
check_tool "git-cliff"         "brew"       "git-cliff --version"
check_tool "cog"               "brew"       "cog --version"            "cocogitto"
check_tool "gh"                "brew"       "gh --version"

# ── Navigation & search ─────────────────────────────────────────────────────
echo "── Navigation & search ──"
check_tool "fzf"               "brew"       "fzf --version"
check_tool "zoxide"            "brew"       "zoxide --version"
check_tool "fd"                "brew"       "fd --version"
check_tool "rg"                "brew"       "rg --version"             "ripgrep"

# ── File viewing ─────────────────────────────────────────────────────────────
echo "── File viewing ──"
check_tool "bat"               "brew"       "bat --version"
check_tool "glow"              "brew"       "glow --version"
check_tool "lnav"              "brew"       "lnav -V"

# ── Process monitoring ───────────────────────────────────────────────────────
echo "── Process monitoring ──"
check_tool "btop"              "brew"       "btop --version"

# ── Terminal multiplexer ─────────────────────────────────────────────────────
echo "── Terminal multiplexer ──"
check_tool "tmux"              "brew"       "tmux -V"

# ── Data wrangling ───────────────────────────────────────────────────────────
echo "── Data wrangling ──"
check_tool "jq"                "brew"       "jq --version"
check_tool "yq"                "brew"       "yq --version"
check_tool "mlr"               "brew"       "mlr --version"            "miller"
check_tool "http"              "brew"       "http --version"           "httpie"

# ── Utilities ────────────────────────────────────────────────────────────────
echo "── Utilities ──"
check_tool "tree"              "brew"       "tree --version"
check_tool "wget"              "brew"       "wget --version"

# ── Version management ───────────────────────────────────────────────────────
echo "── Version management ──"
check_tool "mise"              "brew"       "mise --version"
check_tool "uv"                "brew"       "uv --version"

# ── Neovim ───────────────────────────────────────────────────────────────────
echo "── Neovim ──"
check_tool "nvim"              "brew"       "nvim --version"           "neovim"
check_tool "node"              "mise"       "node --version"           "nodejs@lts"

# ── Python quality ───────────────────────────────────────────────────────────
echo "── Python quality (uv tools) ──"
check_tool "ty"                "uv-tool"    "ty --version"             "ty@latest"
check_tool "prek"              "uv-tool"    "prek --version"           "prek"

# ── Go quality ───────────────────────────────────────────────────────────────
echo "── Go quality ──"
check_tool "golangci-lint"     "brew"       "golangci-lint --version"
check_tool "gofumpt"           "brew"       "gofumpt --version"

# ── Bash quality ─────────────────────────────────────────────────────────────
echo "── Bash quality ──"
check_tool "shellcheck"        "brew"       "shellcheck --version"
check_tool "shfmt"             "brew"       "shfmt --version"

# ── Terraform quality ────────────────────────────────────────────────────────
echo "── Terraform quality ──"
check_tool "tflint"            "brew"       "tflint --version"

# ── GitHub Actions quality ───────────────────────────────────────────────────
echo "── GitHub Actions quality ──"
check_tool "actionlint"        "brew"       "actionlint --version"
check_tool "zizmor"            "brew"       "zizmor --version"
check_tool "pinact"            "brew"       "pinact --version"

# ── Kubernetes ───────────────────────────────────────────────────────────────
echo "── Kubernetes ──"
check_tool "kubectl"           "brew"       "kubectl version --client"  "kubernetes-cli"
check_tool "k9s"               "brew"       "k9s version --short"
check_tool "kubectx"           "brew"       "kubectx --version"

# ── Container ────────────────────────────────────────────────────────────────
echo "── Container ──"
check_tool "lazydocker"        "brew"       "lazydocker --version"
check_tool "podman"            "brew"       "podman --version"

# ── Terraform extras ─────────────────────────────────────────────────────────
echo "── Terraform extras ──"
check_tool "tenv"              "brew"       "tenv --version"
check_tool "tf-summarize"      "brew"       "tf-summarize -v"

# ── Terminal recording ───────────────────────────────────────────────────────
echo "── Terminal recording ──"
check_tool "vhs"               "brew"       "vhs --version"
check_tool "freeze"            "brew"       "freeze --version"         "charmbracelet/tap/freeze"
check_tool "asciinema"         "brew"       "asciinema --version"

# ── OpenCode + critique ──────────────────────────────────────────────────────
echo "── OpenCode + critique ──"
check_tool "opencode"          "bun-global" "opencode --version"       "opencode-ai"
check_tool "critique"          "bun-global" "critique --version"       "critique"

# ── direnv ───────────────────────────────────────────────────────────────────
echo "── direnv ──"
check_tool "direnv"            "brew"       "direnv --version"

# ── Document tools ──────────────────────────────────────────────────────────
echo "── Document tools ──"
check_tool "pandoc"            "brew"       "pandoc --version"
check_tool "typst"             "brew"       "typst --version"

# ── GCP ─────────────────────────────────────────────────────────────────────
echo "── GCP ──"
check_tool "gcloud"            "brew"       "gcloud --version"         "google-cloud-sdk"
check_tool "cloud-sql-proxy"   "brew"       "cloud-sql-proxy --version"
check_tool "bq"                "skip"       "bq --version"

# ── Security ────────────────────────────────────────────────────────────────
echo "── Security ──"
check_tool "codeql"            "brew"       "codeql --version"

# ── Markdown ────────────────────────────────────────────────────────────────
echo "── Markdown ──"
check_tool "markdownlint-cli2" "brew"       "markdownlint-cli2 --help"

# ── VS Code (optional) ─────────────────────────────────────────────────────
echo "── VS Code (optional) ──"
check_tool "code"              "skip"       "code --version"

# ── Go formatting ──────────────────────────────────────────────────────────
echo "── Go formatting ──"
check_tool "goimports"         "brew"       "goimports --help"

echo ""
echo "============================================"
echo "  Results"
echo "============================================"
echo ""

for r in "${results[@]}"; do
  echo -e "$r"
done

echo ""
echo "============================================"
printf "  ${GREEN}PASS: %d${RESET}  ${RED}FAIL: %d${RESET}  ${YELLOW}SKIP: %d${RESET}\n" "$PASS" "$FAIL" "$SKIP"
echo "============================================"

if (( FAIL > 0 || SKIP > 0 )); then
  echo ""
  if (( FAIL > 0 )); then
    echo "Failed tools may be blocked by binary signature policy."
    echo "For each FAIL, try: brew install --build-from-source <formula>"
    echo "If that also fails, the tool needs a local toolchain (Rust/Go/etc)."
    echo ""
    echo "Required toolchains for source builds:"
    echo "  - Xcode CLT:  xcode-select --install"
    echo "  - Rust:        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo "  - Go:          mise install go@latest (already in dotfiles)"
  fi

  if $DIAGNOSE && (( ${#diagnostics[@]} > 0 )); then
    echo ""
    echo "============================================"
    echo "  Diagnostics"
    echo "============================================"
    for d in "${diagnostics[@]}"; do
      echo -e "$d"
    done
  elif (( FAIL > 0 || SKIP > 0 )); then
    echo ""
    echo "Re-run with --diagnose for detailed failure/skip diagnostics:"
    echo "  bash $0 --diagnose"
  fi

  exit 1
fi
