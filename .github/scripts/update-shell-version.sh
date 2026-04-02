#!/usr/bin/env bash
set -euo pipefail

metadata_file="src/metadata.json"
api_url="https://gitlab.gnome.org/api/v4/projects/GNOME%2Fgnome-shell/releases"

current_max="$(jq -r '."shell-version" | map(tonumber) | max' "$metadata_file")"

latest_major="$({
  page=1
  while :; do
    page_data="$(curl -fsSL "${api_url}?per_page=100&page=${page}")"
    if [[ "$(jq 'length' <<<"${page_data}")" -eq 0 ]]; then
      break
    fi

    jq -r '.[].tag_name' <<<"${page_data}"
    page=$((page + 1))
  done
} | awk -F. '/^[0-9]+\.[0-9]+$/ {print $1}' | sort -n | tail -n1)"

if [[ -z "${latest_major}" ]]; then
  echo "Impossible de déterminer la dernière version majeure de GNOME Shell." >&2
  exit 1
fi

if [[ "${latest_major}" -le "${current_max}" ]]; then
  echo "shell-version est déjà à jour (${current_max})."
  exit 0
fi

tmp_file="$(mktemp)"
jq --argjson latest "${latest_major}" '
  ."shell-version" |= (
    map(tonumber) as $versions
    | ($versions | max) as $current_max
    | if $latest <= $current_max then
        $versions
      else
        $versions + [range($current_max + 1; $latest + 1)]
      end
    | map(tostring)
  )
' "$metadata_file" > "$tmp_file"
mv "$tmp_file" "$metadata_file"

echo "shell-version mis à jour jusqu'à ${latest_major}."
