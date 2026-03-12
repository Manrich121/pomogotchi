#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}

input_path=${1:-"$repo_root/assets/icons/app_icon.png"}
output_dir=${2:-"$repo_root/assets/icons"}
sizes=(1024 512 256 128 64 32 16)

if ! command -v sips >/dev/null 2>&1; then
  echo "error: sips is required but not installed" >&2
  exit 1
fi

if [[ ! -f "$input_path" ]]; then
  echo "error: input file not found: $input_path" >&2
  exit 1
fi

mkdir -p "$output_dir"

input_filename=${input_path:t}
input_stem=${input_filename:r}

for size in $sizes; do
  output_path="$output_dir/${input_stem}_${size}.png"
  sips -z "$size" "$size" "$input_path" --out "$output_path" >/dev/null
  echo "created $output_path"
done
