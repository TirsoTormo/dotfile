#!/usr/bin/env bash
# =============================================================================
#  terminal/install.sh — one-shot terminal setup for Debian / Ubuntu
#
#  Installs and configures:
#    ghostty    Ghostty terminal + DepartureMono Nerd Font + Apple System Colors
#    zsh        zsh + Oh My Zsh + xiong-chiamiov theme + plugins
#    cli        eza, bat, zoxide, ripgrep, fd, fzf
#    fastfetch  fastfetch with an image logo
#
#  Usage:
#    ./install.sh                  # everything
#    ./install.sh zsh cli          # only the steps you name
#    ./install.sh --list           # show available steps
#    ./install.sh --no-font        # skip the Nerd Font download
#
#  Safe to run more than once: anything already in place is skipped, and any
#  config it would overwrite is backed up first.
# =============================================================================

set -euo pipefail

# --- Paths -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
BACKUP_DIR="$HOME/.dotfile-backup/$(date +%Y%m%d-%H%M%S)"

# --- Settings (override with env vars) ---------------------------------------
FONT_NAME="${FONT_NAME:-DepartureMono}"
GHOSTTY_THEME="${GHOSTTY_THEME:-Apple System Colors}"
INSTALL_FONT="${INSTALL_FONT:-1}"

ALL_STEPS=(ghostty zsh cli fastfetch)

# =============================================================================
#  Output helpers
# =============================================================================
if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'; C_BLUE=$'\e[34m'; C_GREEN=$'\e[32m'
  C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_DIM=$'\e[2m'; C_BOLD=$'\e[1m'
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""
fi

info() { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%s  !!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
skip() { printf '%s  ..%s %s\n' "$C_DIM"    "$C_RESET" "$*"; }
die()  { printf '%s  xx%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }

header() {
  printf '\n%s%s%s\n' "$C_BOLD" "$1" "$C_RESET"
  printf '%s────────────────────────────────────────%s\n' "$C_BLUE" "$C_RESET"
}

# =============================================================================
#  System helpers
# =============================================================================
have() { command -v "$1" >/dev/null 2>&1; }

require_no_root() {
  [[ $EUID -ne 0 ]] || die "Don't run this as root. Use your own user; it will ask for sudo when needed."
}

require_debian() {
  [[ -f /etc/debian_version ]] || die "This script targets Debian/Ubuntu systems."
}

# Ask for sudo once, then keep the timestamp alive for the whole run.
keep_sudo_alive() {
  have sudo || die "sudo is not installed."
  info "Administrator rights are needed to install packages."
  sudo -v || die "Could not obtain sudo."
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

# Fills DISTRO_ID (debian, ubuntu, linuxmint...) and DISTRO_CODENAME (bookworm, noble...)
detect_distro() {
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO_ID="${ID:-unknown}"
  DISTRO_LIKE="${ID_LIKE:-}"
  DISTRO_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-stable}}"
}

is_ubuntu_family() {
  detect_distro
  [[ "$DISTRO_ID" == "ubuntu" || "$DISTRO_LIKE" == *ubuntu* ]]
}

is_debian_family() {
  detect_distro
  [[ "$DISTRO_ID" == "debian" || "$DISTRO_LIKE" == *debian* ]]
}

# =============================================================================
#  apt helpers
# =============================================================================
APT_UPDATED=0

apt_update_once() {
  [[ $APT_UPDATED -eq 1 ]] && return 0
  info "Refreshing apt indexes..."
  sudo apt-get update -qq
  APT_UPDATED=1
}

apt_install() {
  local pkgs=() p
  for p in "$@"; do
    if dpkg -s "$p" >/dev/null 2>&1; then
      skip "$p already installed"
    else
      pkgs+=("$p")
    fi
  done
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  apt_update_once
  info "Installing: ${pkgs[*]}"
  sudo apt-get install -y -qq "${pkgs[@]}"
  ok "Installed: ${pkgs[*]}"
}

# Does apt have an installable candidate for this package?
# LC_ALL=C keeps apt-cache's output in English regardless of the user's
# locale -- otherwise the grep below never matches on e.g. a Spanish system,
# where "Candidate:" is printed as "Candidato:".
apt_has_candidate() {
  apt_update_once
  local policy
  policy="$(LC_ALL=C apt-cache policy "$1" 2>/dev/null)" || return 1
  [[ -n "$policy" ]] || return 1
  grep -q 'Candidate:' <<<"$policy" && ! grep -q 'Candidate: (none)' <<<"$policy"
}

# add_apt_repo <key-url> <keyring-path> <deb-line> <list-name>
add_apt_repo() {
  local key_url="$1" keyring="$2" deb_line="$3" list_name="$4"
  [[ -f "$keyring" ]] && { skip "repo $list_name already added"; return 0; }
  apt_install curl gpg
  info "Adding apt repository: $list_name"
  sudo mkdir -p "$(dirname "$keyring")"
  curl -fsSL "$key_url" | sudo gpg --yes --dearmor -o "$keyring"
  sudo chmod 644 "$keyring"
  echo "$deb_line" | sudo tee "/etc/apt/sources.list.d/${list_name}.list" >/dev/null
  APT_UPDATED=0
}

# =============================================================================
#  Symlinks (with backup)
# =============================================================================
# link_config <source-in-repo> <destination-in-home>
link_config() {
  local src="$1" dest="$2"

  [[ -e "$src" ]] || { warn "Missing $src, skipping."; return 0; }

  if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    skip "$dest already linked"
    return 0
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dest" "$BACKUP_DIR/$(basename "$dest")"
    warn "Existing config moved to $BACKUP_DIR/$(basename "$dest")"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  ok "Linked $dest -> $src"
}

# =============================================================================
#  Nerd Font
# =============================================================================
install_nerd_font() {
  local name="$1"
  local font_dir="$HOME/.local/share/fonts/${name}NerdFont"

  if [[ "$INSTALL_FONT" != "1" ]]; then
    skip "font install disabled (--no-font)"
    return 0
  fi

  if fc-list 2>/dev/null | grep -qi "${name} Nerd Font"; then
    skip "${name} Nerd Font already installed"
    return 0
  fi

  apt_install curl unzip fontconfig
  info "Installing ${name} Nerd Font..."

  local tmp; tmp="$(mktemp -d)"
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${name}.zip"

  if ! curl -fsSL "$url" -o "$tmp/font.zip"; then
    warn "Could not download ${name}.zip. Continuing without the font."
    rm -rf "$tmp"; return 0
  fi

  mkdir -p "$font_dir"
  unzip -qo "$tmp/font.zip" -d "$font_dir" -x '*.txt' '*.md' 'LICENSE*' || true
  fc-cache -f >/dev/null
  rm -rf "$tmp"
  ok "${name} Nerd Font installed"
}

# =============================================================================
#  STEP: ghostty
# =============================================================================
# Ghostty only ships in the official repos on Ubuntu 26.04+. Everywhere else we
# fall back to a community package source.
install_ghostty() {
  if have ghostty; then skip "ghostty already installed"; return 0; fi

  detect_distro

  if apt_has_candidate ghostty; then
    info "Ghostty is available in your system repositories."
    apt_install ghostty
    return 0
  fi

  if is_ubuntu_family; then
    info "Ubuntu detected: using the community PPA (mkasberg)."
    apt_install software-properties-common
    sudo add-apt-repository -y ppa:mkasberg/ghostty-ubuntu
    APT_UPDATED=0
    apt_install ghostty
    return 0
  fi

  if is_debian_family; then
    info "Debian detected: using the community repo (deb.griffo.io)."
    add_apt_repo \
      "https://deb.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc" \
      "/usr/share/keyrings/deb.griffo.io.gpg" \
      "deb [signed-by=/usr/share/keyrings/deb.griffo.io.gpg] https://deb.griffo.io/apt ${DISTRO_CODENAME} main" \
      "deb.griffo.io"
    apt_install ghostty
    return 0
  fi

  die "Don't know how to install Ghostty on '$DISTRO_ID'. See https://ghostty.org/docs/install/binary"
}

# Some Linux packages don't ship the full theme collection. If ours is missing,
# drop it into ~/.config/ghostty/themes/ ourselves.
ensure_ghostty_theme() {
  if ghostty +list-themes 2>/dev/null | grep -qiF "$GHOSTTY_THEME"; then
    skip "theme '$GHOSTTY_THEME' already available"
    return 0
  fi

  info "Theme '$GHOSTTY_THEME' not bundled with your package. Downloading it."
  local dir="$HOME/.config/ghostty/themes"
  mkdir -p "$dir"

  local url="https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/ghostty/${GHOSTTY_THEME// /%20}"
  if curl -fsSL "$url" -o "$dir/$GHOSTTY_THEME"; then
    ok "Theme saved to $dir/$GHOSTTY_THEME"
  else
    warn "Download failed. Ghostty will use its default colors."
    rm -f "$dir/$GHOSTTY_THEME"
  fi
}

set_default_terminal() {
  local bin; bin="$(command -v ghostty)" || return 0

  info "Setting Ghostty as the default terminal..."
  sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$bin" 60 >/dev/null
  sudo update-alternatives --set x-terminal-emulator "$bin" >/dev/null
  ok "x-terminal-emulator -> $bin"

  if have gsettings && gsettings writable org.gnome.desktop.default-applications.terminal exec >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.default-applications.terminal exec "$bin"
    ok "GNOME: Ctrl+Alt+T -> ghostty"
  fi
}

step_ghostty() {
  header "1/4  Ghostty"
  install_ghostty
  install_nerd_font "$FONT_NAME"
  link_config "$CONFIG_DIR/ghostty/config" "$HOME/.config/ghostty/config"
  ensure_ghostty_theme
  set_default_terminal
}

# =============================================================================
#  STEP: zsh
# =============================================================================
OMZ_DIR="$HOME/.oh-my-zsh"
OMZ_CUSTOM="$OMZ_DIR/custom"

# External plugins. 'git' and 'history-substring-search' already ship with Oh My Zsh.
declare -A ZSH_PLUGINS=(
  [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
  [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting"
  [zsh-completions]="https://github.com/zsh-users/zsh-completions"
  [fzf-tab]="https://github.com/Aloxaf/fzf-tab"
)

install_oh_my_zsh() {
  if [[ -d "$OMZ_DIR" ]]; then skip "Oh My Zsh already installed"; return 0; fi
  info "Installing Oh My Zsh..."
  # RUNZSH=no    -> don't drop into zsh and cut this script short
  # CHSH=no      -> we change the login shell ourselves below
  # KEEP_ZSHRC   -> don't generate a .zshrc, we link our own
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  ok "Oh My Zsh installed"
}

install_zsh_plugins() {
  local name repo dest
  for name in "${!ZSH_PLUGINS[@]}"; do
    repo="${ZSH_PLUGINS[$name]}"
    dest="$OMZ_CUSTOM/plugins/$name"
    if [[ -d "$dest/.git" ]]; then
      skip "plugin $name present, pulling updates"
      git -C "$dest" pull --quiet --ff-only || warn "could not update $name"
    else
      info "Cloning plugin $name..."
      git clone --depth=1 --quiet "$repo" "$dest"
      ok "$name"
    fi
  done
}

set_default_shell() {
  local zsh_bin; zsh_bin="$(command -v zsh)"

  if [[ "${SHELL:-}" == "$zsh_bin" ]]; then
    skip "zsh is already your login shell"
    return 0
  fi

  grep -qxF "$zsh_bin" /etc/shells || echo "$zsh_bin" | sudo tee -a /etc/shells >/dev/null

  info "Changing your login shell to zsh..."
  if sudo chsh -s "$zsh_bin" "$USER"; then
    ok "Login shell set to zsh (takes effect after you log out and back in)"
  else
    warn "Failed. Do it manually: chsh -s $zsh_bin"
  fi
}

step_zsh() {
  header "2/4  zsh + Oh My Zsh"
  apt_install zsh git curl fzf   # fzf is required by fzf-tab
  install_oh_my_zsh
  install_zsh_plugins
  link_config "$CONFIG_DIR/zsh/.zshrc" "$HOME/.zshrc"
  set_default_shell
}

# =============================================================================
#  STEP: cli
# =============================================================================
install_eza() {
  if have eza; then skip "eza already installed"; return 0; fi

  if apt_has_candidate eza; then
    apt_install eza
    return 0
  fi

  # Not packaged on Debian 12 / Ubuntu 22.04: use the official eza repo.
  info "eza is not in your repos. Adding the official one."
  add_apt_repo \
    "https://raw.githubusercontent.com/eza-community/eza/main/deb.asc" \
    "/etc/apt/keyrings/gierens.gpg" \
    "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    "gierens"
  apt_install eza
}

# On Debian/Ubuntu these binaries are renamed to avoid clashing with other
# packages. Expose the usual names from ~/.local/bin.
fix_debian_binary_names() {
  mkdir -p "$HOME/.local/bin"
  if have batcat && ! have bat; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    ok "~/.local/bin/bat -> batcat"
  fi
  if have fdfind && ! have fd; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    ok "~/.local/bin/fd -> fdfind"
  fi
}

step_cli() {
  header "3/4  CLI tools"
  apt_install bat zoxide ripgrep fd-find fzf
  install_eza
  fix_debian_binary_names
}

# =============================================================================
#  STEP: fastfetch
# =============================================================================
install_fastfetch() {
  if have fastfetch; then skip "fastfetch already installed"; return 0; fi

  if apt_has_candidate fastfetch; then
    apt_install fastfetch
    return 0
  fi

  if is_ubuntu_family; then
    info "fastfetch is not in your repos. Using the upstream PPA."
    apt_install software-properties-common
    sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
    APT_UPDATED=0
    apt_install fastfetch
    return 0
  fi

  info "Downloading the fastfetch .deb from GitHub releases..."
  apt_install curl
  local arch tmp url
  arch="$(dpkg --print-architecture)"
  tmp="$(mktemp -d)"
  url="$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
        | grep -oP "https://[^\"]+fastfetch-linux-${arch}\.deb" | head -n1)"
  [[ -n "$url" ]] || die "No fastfetch .deb found for $arch."
  curl -fsSL "$url" -o "$tmp/fastfetch.deb"
  sudo apt-get install -y "$tmp/fastfetch.deb"
  rm -rf "$tmp"
  ok "fastfetch installed"
}

step_fastfetch() {
  header "4/4  fastfetch"
  install_fastfetch
  link_config "$CONFIG_DIR/fastfetch" "$HOME/.config/fastfetch"
  chmod +x "$CONFIG_DIR/fastfetch/ff-random.sh"

  local logo_count
  logo_count=$(find "$CONFIG_DIR/fastfetch/logos" -maxdepth 1 -name '[0-9]*.png' | wc -l)
  if [[ "$logo_count" -gt 0 ]]; then
    ok "$logo_count carousel logo(s) found"
  else
    warn "No logos yet. Drop numbered PNGs at terminal/config/fastfetch/logos/"
    warn "or run: ff-logo ~/Pictures/whatever.png"
  fi
}

# =============================================================================
#  Main
# =============================================================================
usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

main() {
  local steps=()

  for arg in "$@"; do
    case "$arg" in
      -h|--help)  usage ;;
      --list)     printf '%s\n' "${ALL_STEPS[@]}"; exit 0 ;;
      --no-font)  INSTALL_FONT=0 ;;
      ghostty|zsh|cli|fastfetch) steps+=("$arg") ;;
      *) die "Unknown argument: $arg  (try --help)" ;;
    esac
  done

  [[ ${#steps[@]} -eq 0 ]] && steps=("${ALL_STEPS[@]}")

  require_no_root
  require_debian
  keep_sudo_alive

  printf '\n%sTerminal setup%s — steps: %s\n' "$C_BOLD" "$C_RESET" "${steps[*]}"

  for step in "${steps[@]}"; do
    "step_${step}"
  done

  header "Done"
  ok "Log out and back in so the login shell and default terminal take effect."
  [[ -d "$BACKUP_DIR" ]] && info "Replaced configs were backed up to $BACKUP_DIR"
  echo
}

main "$@"
