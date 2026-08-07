# terminal

My terminal setup for Debian / Ubuntu. One script, one command, and a fresh
machine ends up with the exact same shell I use every day.

| Tool | What it is |
| --- | --- |
| [Ghostty](https://ghostty.org) | GPU-accelerated terminal emulator |
| DepartureMono Nerd Font | Pixel font, patched with icon glyphs |
| Apple System Colors | Color theme |
| zsh + [Oh My Zsh](https://ohmyz.sh) | Shell, `xiong-chiamiov` theme |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | System info banner with an image logo |
| eza, bat, zoxide, ripgrep, fd, fzf | Modern replacements for ls, cat, cd, grep, find |

## Install

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/TirsoTormo/dotfile.git ~/dotfile
cd ~/dotfile/terminal
chmod +x install.sh
./install.sh
```

Then **log out and back in** — the login shell and the default terminal only
change on a new session.

### Options

```bash
./install.sh --list        # show the available steps
./install.sh zsh cli       # run only those steps
./install.sh --no-font     # skip the Nerd Font download
./install.sh --help        # usage
```

Steps: `ghostty`, `zsh`, `cli`, `fastfetch`.

If `./install.sh` says *permission denied*, the executable bit was lost. Fix it
once and commit it so it survives future clones:

```bash
chmod +x install.sh
git update-index --chmod=+x install.sh
```

## Layout

```
terminal/
├── install.sh
└── config/
    ├── ghostty/config       -> ~/.config/ghostty/config
    ├── zsh/.zshrc           -> ~/.zshrc
    └── fastfetch/           -> ~/.config/fastfetch
        ├── config.jsonc
        └── logos/current.png   (your image goes here)
```

Configs are **symlinked**, not copied. Edit a file in this repo and the change
applies immediately; `git push` carries it to every other machine.

## The fastfetch logo

The config draws a real PNG using the Kitty graphics protocol, which Ghostty
supports. Put your image at `config/fastfetch/logos/current.png`, or from the
shell:

```bash
ff-logo ~/Pictures/whatever.png
```

Without an image fastfetch still prints all the system info, it just complains
about the missing logo.

## Safety

- **Idempotent.** Run it as many times as you like; anything already installed
  or linked is skipped.
- **Nothing gets destroyed.** An existing `~/.zshrc` or `~/.config/ghostty` is
  moved to `~/.dotfile-backup/<timestamp>/` before the symlink is created.
- **No root.** Run it as your normal user; it asks for sudo once.

## Notes and gotchas

- **Ghostty packaging.** It only ships in the official repos on Ubuntu 26.04+.
  Elsewhere the script falls back to the community PPA `mkasberg/ghostty-ubuntu`
  (Ubuntu) or `deb.griffo.io` (Debian). Note that deb.griffo.io moves to a paid
  subscription for apt access from October 2026; the raw `.deb` files stay free
  on GitHub.
- **`background-blur` barely works on Linux.** Only KDE Plasma supports it out
  of the box; GNOME needs the *Blur My Shell* extension, and other desktops
  ignore it silently. Transparency (`background-opacity`) works everywhere. On
  KDE the intensity value is ignored — the compositor's global blur wins.
- **`grep` is aliased to `rg`.** Convenient, but ripgrep does not accept the
  same flags. Use `\grep` when you need the real thing.
- **`eza`** is not packaged on Debian 12 or Ubuntu 22.04, so the script adds the
  official eza apt repo there.
- **Plugin order in `.zshrc` is deliberate.** `fzf-tab` must load before
  anything that wraps zsh widgets, and `zsh-syntax-highlighting` must be last.
  Reordering them breaks completion.

## Changing things

Font, theme and font install can be overridden without editing the script:

```bash
FONT_NAME=JetBrainsMono GHOSTTY_THEME="Catppuccin Mocha" ./install.sh ghostty
```
