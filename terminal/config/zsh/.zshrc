# ~/.zshrc (symlinked from this repo)

# --- Oh My Zsh -----------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="xiong-chiamiov"

# Plugin order is deliberate: fzf-tab must load before anything that wraps
# zsh widgets, and zsh-syntax-highlighting must always be last.
plugins=(
  git
  history-substring-search
  zsh-autosuggestions
  zsh-completions
  fzf-tab
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# --- PATH ------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"

# --- Modern CLI replacements -------------------------------------------------
alias ls='eza --icons'
alias ll='eza -l --icons'
alias la='eza -la --icons'
alias tree='eza --tree --icons'
alias cat='bat'
alias grep='rg'   # ripgrep doesn't accept the same flags; use \grep for the real thing

eval "$(zoxide init zsh)"
alias cd='z'

# --- fastfetch ---------------------------------------------------------------
# Cycles through the logos in ~/.config/fastfetch/logos on every new shell.
if command -v fastfetch >/dev/null 2>&1; then
  "$HOME/.config/fastfetch/ff-random.sh"
fi

# Set a single custom fastfetch logo, overriding the carousel until it's
# replaced again: ff-logo ~/Pictures/whatever.png
ff-logo() {
  if [[ -z "$1" ]]; then
    echo "usage: ff-logo <path-to-image>" >&2
    return 1
  fi
  cp "$1" "$HOME/.config/fastfetch/logos/current.png"
}
