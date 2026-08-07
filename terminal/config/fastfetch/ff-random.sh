#!/usr/bin/env bash
# Rotates the fastfetch logo shown on each new shell: on every call it
# symlinks the next numbered PNG in logos/ to logos/current.png, then runs
# fastfetch. Logos are cycled but colors are not, since this config's
# keyColors are fixed rather than templated.
#
# Adapted from the logo-carousel idea in
# https://github.com/zakf4-blip/fastfetch-carousel (ff-random.sh), stripped
# of its per-logo color rotation to match this repo's static color scheme.
set -euo pipefail

FASTFETCH_CONF="$HOME/.config/fastfetch"
LOGO_DIR="$FASTFETCH_CONF/logos"
COUNTER_FILE="$LOGO_DIR/.counter.txt"

IMAGES=("$LOGO_DIR"/[0-9]*.png)
TOTAL_IMAGES=${#IMAGES[@]}

if [[ "$TOTAL_IMAGES" -eq 0 ]]; then
  fastfetch --config "$FASTFETCH_CONF/config.jsonc"
  exit 0
fi

COUNTER=0
[[ -f "$COUNTER_FILE" ]] && read -r COUNTER <"$COUNTER_FILE"

NEXT=$(( (COUNTER % TOTAL_IMAGES) + 1 ))
echo "$NEXT" > "$COUNTER_FILE"

ln -sf "$LOGO_DIR/${NEXT}.png" "$LOGO_DIR/current.png"

fastfetch --config "$FASTFETCH_CONF/config.jsonc"
