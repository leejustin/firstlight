#!/bin/zsh
# Regenerates Firstlight/Resources/Sounds/*.caf from tools/generate_sounds.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

swiftc -O tools/generate_sounds.swift -o "$work/gensounds"
"$work/gensounds" "$work"

out=Firstlight/Resources/Sounds
mkdir -p "$out"
for wav in "$work"/*.wav; do
  name=$(basename "$wav" .wav)
  # IMA4 in CAF loops cleanly in AVAudioPlayer and is a format AlarmKit accepts.
  afconvert -f caff -d ima4 "$wav" "$out/$name.caf"
  echo "  $out/$name.caf"
done
