#!/usr/bin/env bash
# Register every configured provider in OpenCode's global config
# (`make opencode-global`). OpenCode has no launcher in this repo: a bare
# `opencode` reads the generated ~/.config/opencode/opencode.json, and /models
# lists every provider.
#
# .env stays the single source of truth: the config references each token as
# {file:...} pointing at a token file this script writes next to it (chmod
# 600), so the config itself carries no secrets. Re-run after editing any
# .env — the token copies are replaced.

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROVIDERS_DIR="$ROOT/providers"
# shellcheck disable=SC1090
source "$ROOT/bin/common.sh"

OUT=$(opencode_global_config_path)
CONFIG_DIR=$(dirname "$OUT")
TOKENS_DIR=$(opencode_tokens_dir)

if [ -f "$OUT" ] && [ "$(head -1 "$OUT")" != "$OPENCODE_GLOBAL_MARKER" ]; then
  echo "opencode-global: $OUT already exists and was not generated here." >&2
  echo "  merge it by hand, or move it aside and re-run 'make opencode-global'." >&2
  exit 1
fi

# Provider the session's model / small_model default to; the first configured
# provider when unset.
default_provider="${OPENCODE_DEFAULT_PROVIDER:-}"
first_provider=

providers=()
tokens=()
entries=()
for dir in "$PROVIDERS_DIR"/*/; do
  provider=$(basename "$dir")
  env_file="$dir.env"
  [ -f "$env_file" ] || continue
  # Each provider is resolved in a subshell: load_settings exports the whole
  # .env, and providers must not leak into each other. The token rides on the
  # first line of the record; the JSON block follows.
  entry=$(
    load_settings "$env_file"
    [ -n "$CFG_TOKEN" ] && [ -n "$CFG_BASE_URL" ] && [ -n "$CFG_MODEL" ] || exit 0
    opencode_resolve
    printf '%s\n' "$CFG_TOKEN"
    opencode_provider_json "$provider" "{file:$TOKENS_DIR/$provider.token}"
  )
  if [ -n "$entry" ]; then
    providers+=("$provider")
    tokens+=("${entry%%$'\n'*}")
    entries+=("${entry#*$'\n'}")
    [ -n "$first_provider" ] || first_provider=$provider
  fi
done

if [ "${#entries[@]}" -eq 0 ]; then
  echo "opencode-global: no provider has a token yet — run 'make setup' first." >&2
  exit 1
fi

if [ -n "$default_provider" ]; then
  found=0
  for p in "${providers[@]}"; do
    [ "$p" = "$default_provider" ] && found=1
  done
  if [ "$found" != 1 ]; then
    echo "opencode-global: OPENCODE_DEFAULT_PROVIDER=$default_provider has no token — pick one of: ${providers[*]}" >&2
    exit 1
  fi
else
  default_provider=$first_provider
fi

default_models=$(
  load_settings "$PROVIDERS_DIR/$default_provider/.env"
  opencode_resolve
  printf '%s\n%s' "$OC_CFG_MODEL" "$OC_CFG_SMALL_MODEL"
)
model="$default_provider-anthropic/$(head -1 <<<"$default_models")"
small_model="$default_provider-anthropic/$(tail -n +2 <<<"$default_models")"

# The tokens dir is fully managed here: wipe it, then write the current set so
# providers whose .env lost their token leave no stale secret behind.
mkdir -p "$TOKENS_DIR"
chmod 700 "$TOKENS_DIR"
rm -f "$TOKENS_DIR"/*.token
for i in "${!providers[@]}"; do
  printf '%s' "${tokens[$i]}" > "$TOKENS_DIR/${providers[$i]}.token"
  chmod 600 "$TOKENS_DIR/${providers[$i]}.token"
done

mkdir -p "$CONFIG_DIR"
{
  printf '%s\n' "$OPENCODE_GLOBAL_MARKER"
  echo '{'
  echo '  "$schema": "https://opencode.ai/config.json",'
  echo '  "provider": {'
  for i in "${!entries[@]}"; do
    printf '%s' "${entries[$i]}"
    if [ "$i" -lt $(( ${#entries[@]} - 1 )) ]; then echo ','; fi
  done
  echo '  },'
  printf '  "model": "%s",\n' "$model"
  printf '  "small_model": "%s"\n' "$small_model"
  echo '}'
} > "$OUT"

echo "  Wrote $OUT (${#entries[@]} providers, default $model)"
