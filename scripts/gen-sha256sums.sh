#!/usr/bin/env bash
# Aggregate checksum list for one release: <assets-dir> holds exactly the
# release assets, <list-file> holds one "<sha256>  <basename>" row per asset.
set -euo pipefail

usage() {
  printf 'usage: %s gen <assets-dir> <list-file>\n' "$0" >&2
  printf '       %s check <assets-dir> <list-file> [expected-rows]\n' "$0" >&2
  exit 2
}

[ $# -ge 3 ] && [ $# -le 4 ] || usage
mode=$1
dir=$2
list=$3
[ $# -eq 4 ] && expected=$4 || expected=""
if [ -n "$expected" ]; then
  case $expected in
    *[!0-9]*) usage ;;
  esac
fi
list_dir=${list%/*}
list_name=${list##*/}
[ "$list_dir" != "$list" ] || usage
[ -d "$dir" ] || { printf 'ERROR: no such asset directory: %s\n' "$dir" >&2; exit 1; }
[ -d "$list_dir" ] || { printf 'ERROR: no such directory for the list: %s\n' "$list_dir" >&2; exit 1; }
list_abs=$(cd "$list_dir" && pwd)/$list_name

# GNU sha256sum and perl shasum are separate implementations, but both emit
# the two-space text-mode row that `sha256sum -c` reads back.
if command -v sha256sum >/dev/null 2>&1; then
  hasher=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  hasher=(shasum -a 256)
else
  printf 'ERROR: neither sha256sum nor shasum is available\n' >&2
  exit 1
fi

assets() {
  (
    cd "$dir"
    for entry in *; do
      [ -f "$entry" ] || continue
      [ "$entry" = "$list_name" ] && continue
      printf '%s\n' "$entry"
    done
  )
}

case $mode in
gen)
  [ -z "$expected" ] || usage
  if [ -e "$list_abs" ]; then
    printf 'ERROR: %s already exists; delete it and regenerate with the assets\n' "$list" >&2
    exit 1
  fi
  names=$(assets)
  [ -n "$names" ] || { printf 'ERROR: %s holds no assets\n' "$dir" >&2; exit 1; }
  # Rows have to stay parseable by -c: one token, no directory part, no
  # leading dash (it would reach the hasher as an option).
  bad=$(printf '%s\n' "$names" | LC_ALL=C grep -v '^[A-Za-z0-9][A-Za-z0-9._+-]*$' || true)
  if [ -n "$bad" ]; then
    printf 'ERROR: asset names outside [A-Za-z0-9._+-]:\n%s\n' "$bad" >&2
    exit 1
  fi
  (
    cd "$dir"
    printf '%s\n' "$names" | LC_ALL=C sort | xargs -n 1 "${hasher[@]}" | LC_ALL=C sort -k2
  ) > "$list_abs"
  printf 'wrote %s: %s rows\n' "$list" "$(wc -l < "$list_abs" | tr -d '[:space:]')"
  ;;
check)
  [ -f "$list_abs" ] || { printf 'ERROR: no such list: %s\n' "$list" >&2; exit 1; }
  rows=$(wc -l < "$list_abs" | tr -d '[:space:]')
  [ "$rows" -gt 0 ] || { printf 'ERROR: %s holds no rows\n' "$list" >&2; exit 1; }
  if [ -n "$expected" ] && [ "$rows" != "$expected" ]; then
    printf 'ERROR: %s has %s rows, expected %s\n' "$list" "$rows" "$expected" >&2
    exit 1
  fi
  found=$(assets | wc -l | tr -d '[:space:]')
  if [ "$rows" != "$found" ]; then
    printf 'ERROR: %s has %s rows but %s holds %s assets\n' "$list" "$rows" "$dir" "$found" >&2
    exit 1
  fi
  ( cd "$dir" && "${hasher[@]}" -c "$list_abs" )
  ;;
*)
  usage
  ;;
esac
