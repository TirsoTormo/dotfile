# dotfile

My personal configuration files. Clone the repo on a fresh machine, run the
installer for the part you need, and the setup is reproduced exactly.

Target system: **Debian / Ubuntu**.

## Contents

| Folder | What it sets up |
| --- | --- |
| [`terminal/`](terminal) | Ghostty, zsh + Oh My Zsh, fastfetch, and modern CLI tools |

## Quick start

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/TirsoTormo/dotfile.git ~/dotfile
cd ~/dotfile/terminal
chmod +x install.sh
./install.sh
```

Each folder has its own README with the details, options and caveats.

## How it works

Config files are **symlinked** from this repo into your home directory, so
editing a file here changes the live config, and `git push` carries it to every
other machine. Anything the installer would overwrite is backed up to
`~/.dotfile-backup/<timestamp>/` first.

## License

MIT — see [LICENSE](LICENSE).
