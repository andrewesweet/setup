#!/usr/bin/env bash
set -uo pipefail

# test-tool-installs.sh — verify all dotfiles tools install and run on macOS
#
# Usage:
#   bash test-tool-installs.sh              # test all tools
#   bash test-tool-installs.sh --install    # install missing tools first, then test
#
# Output: pass/fail for each tool with the method used to install it.
# Tools that fail the no-op run are likely blocked by binary signature policy.

INSTALL=false
[[ "${1:-}" == "--install" ]] && INSTALL=true

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

PASS=0
FAIL=0
SKIP=0

results=()

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
    results+=("$(printf "${YELLOW}SKIP${RESET}  %-20s  not installed (%s)" "$name" "$install_method")")
    ((SKIP++))
    return
  fi

  local version_output
  if version_output=$(eval "$test_cmd" 2>&1); then
    version_output=$(echo "$version_output" | head -1 | sed 's/^[[:space:]]*//')
    results+=("$(printf "${GREEN}PASS${RESET}  %-20s  %-14s  %s" "$name" "$install_method" "$version_output")")
    ((PASS++))
  else
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
check_tool "node"              "brew"       "node --version"

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
check_tool "kubectx"           "brew"       "kubectx --help"

# ── Container ────────────────────────────────────────────────────────────────
echo "── Container ──"
check_tool "lazydocker"        "brew"       "lazydocker --version"
check_tool "podman"            "brew"       "podman --version"

# ── Terraform extras ─────────────────────────────────────────────────────────
echo "── Terraform extras ──"
check_tool "tenv"              "brew"       "tenv --version"
check_tool "tf-summarize"      "brew"       "tf-summarize --version"

# ── Terminal recording ───────────────────────────────────────────────────────
echo "── Terminal recording ──"
check_tool "vhs"               "brew"       "vhs --version"
check_tool "freeze"            "brew"       "freeze --version"
check_tool "asciinema"         "brew"       "asciinema --version"

# ── OpenCode + critique ──────────────────────────────────────────────────────
echo "── OpenCode + critique ──"
check_tool "opencode"          "bun-global" "opencode --version"       "opencode-ai"
check_tool "critique"          "bun-global" "critique --version"       "critique"

# ── direnv ───────────────────────────────────────────────────────────────────
echo "── direnv ──"
check_tool "direnv"            "brew"       "direnv --version"

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

if (( FAIL > 0 )); then
  echo ""
  echo "Failed tools may be blocked by binary signature policy."
  echo "For each FAIL, try: brew install --build-from-source <formula>"
  echo "If that also fails, the tool needs a local toolchain (Rust/Go/etc)."
  echo ""
  echo "Required toolchains for source builds:"
  echo "  - Xcode CLT:  xcode-select --install"
  echo "  - Rust:        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  echo "  - Go:          mise install go@latest (already in dotfiles)"
  exit 1
fi
