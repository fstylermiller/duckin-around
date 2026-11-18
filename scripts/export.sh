#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
./scripts/check-version.sh

version="$(godot --version | sed 's/\.stable.*//')"
versioned_dir="builds/${version}"
current_dir="builds/current"
mkdir -p "$versioned_dir" "$current_dir"

godot --headless --path game --export-debug "Windows Desktop" "../${versioned_dir}/DuckGame.exe"
cp "${versioned_dir}/DuckGame.exe" "${current_dir}/DuckGame.exe"
printf 'Exported Windows build to %s\n' "${current_dir}/DuckGame.exe"
