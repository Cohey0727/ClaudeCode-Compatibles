#!/usr/bin/env bash
# Register every configured provider in pi's global models.json
# (`make pi-global`). pi has no launcher in this repo: a bare `pi` reads the
# generated ~/.pi/agent/models.json, and /model lists every provider.
#
# Tokens and HEADERS values stay in providers/<name>/.env: the generated file
# only holds shell commands that read them back out at request time, so a
# rotated token or a computed header needs no re-run.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROVIDERS_DIR="$ROOT/providers"
# shellcheck disable=SC1090
source "$ROOT/bin/common.sh"

OUT=$(pi_global_models_path)
AGENT_DIR=$(dirname "$OUT")

if [ -f "$OUT" ] && [ "$(head -1 "$OUT")" != "$PI_GLOBAL_MARKER" ]; then
  echo "pi-global: $OUT already exists and was not generated here." >&2
  echo "  merge it by hand, or move it aside and re-run 'make pi-global'." >&2
  exit 1
fi

pi_global_header_ref() { # <name> -> command pi runs to read the value from .env
  printf "!bash -c '. %s; load_settings %s; header_value %s'" \
    "$ROOT/bin/common.sh" "$env_file" "$1"
}

entries=()
for dir in "$PROVIDERS_DIR"/*/; do
  provider=$(basename "$dir")
  env_file="$dir.env"
  [ -f "$env_file" ] || continue
  # Each provider is resolved in a subshell: load_settings exports the whole
  # .env, and providers must not leak into each other.
  entry=$(
    load_settings "$env_file"
    [ -n "$CFG_TOKEN" ] && [ -n "$CFG_BASE_URL" ] && [ -n "$CFG_MODEL" ] || exit 0
    pi_resolve
    pi_provider_json "$provider-anthropic" \
      "!grep -m1 -E '^(API_TOKEN|ANTHROPIC_AUTH_TOKEN)=.+' '$env_file' | cut -d= -f2-" \
      pi_global_header_ref
  )
  if [ -n "$entry" ]; then entries+=("$entry"); fi
done

if [ "${#entries[@]}" -eq 0 ]; then
  echo "pi-global: no provider has a token yet — run 'make setup' first." >&2
  exit 1
fi

mkdir -p "$AGENT_DIR"
{
  printf '%s\n' "$PI_GLOBAL_MARKER"
  echo '{'
  echo '  "providers": {'
  for i in "${!entries[@]}"; do
    printf '%s' "${entries[$i]}"
    if [ "$i" -lt $(( ${#entries[@]} - 1 )) ]; then echo ','; fi
  done
  echo '  }'
  echo '}'
} > "$OUT"

echo "  Wrote $OUT (${#entries[@]} providers)"
