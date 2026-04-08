# .bash_profile — login shell entry point
# Delegates everything to .bashrc so interactive config works
# identically in login and non-login shells.

# Re-exec under Homebrew Bash 5 if running macOS default Bash 3.2.
# This avoids needing chsh (which requires sudo on corporate Macs).
# Try $HOME/homebrew (custom prefix) then /opt/homebrew (Apple Silicon default)
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
  for _brew_bash in "$HOME/homebrew/bin/bash" /opt/homebrew/bin/bash; do
    if [[ -x "$_brew_bash" ]]; then
      exec "$_brew_bash" --login
    fi
  done
  unset _brew_bash
fi

[[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
