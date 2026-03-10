#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}

input_path=${1:-"$repo_root/assets/Animals.png"}
output_dir=${2:-"$repo_root/assets/smol-animals-crops-icons"}

columns=6
rows=5

# Regular settings
tile_size=80
left_offset=32
top_offset=16
gap=16

# Upscaled settings
# tile_size=200
# left_offset=80
# top_offset=40
# gap=40



step=$((tile_size + gap))

if ! command -v sips >/dev/null 2>&1; then
  echo "error: sips is required but not installed" >&2
  exit 1
fi

if [[ ! -f "$input_path" ]]; then
  echo "error: input file not found: $input_path" >&2
  exit 1
fi

mkdir -p "$output_dir"

for ((row = 0; row < rows; row++)); do
  for ((col = 0; col < columns; col++)); do
    index=$((row * columns + col + 1))
    y=$((top_offset + row * step))
    x=$((left_offset + col * step))
    output_path=$(printf "%s/smol-animal-%02d-icon.png" "$output_dir" "$index")

    sips -c "$tile_size" "$tile_size" --cropOffset "$y" "$x" "$input_path" --out "$output_path" >/dev/null
  done
done

echo "Created 30 cropped images in $output_dir"
