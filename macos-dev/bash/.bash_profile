# .bash_profile — login shell entry point
# Delegates everything to .bashrc so interactive config works
# identically in login and non-login shells.
[[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
