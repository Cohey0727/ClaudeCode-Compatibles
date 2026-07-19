#!/usr/bin/env bash
# Interactive setup for claude-compatibles (`make setup`).
#
#   bin/setup.sh                  checkbox multi-select, then token prompts
#   bin/setup.sh deepseek glm     skip the checkbox, still prompt for tokens
#
# At a token prompt, pressing Enter with no input keeps whatever token is
# already in that provider's .env. Old-format .env files are migrated first.
# Finally the launcher commands are generated from bin/launcher.template
# into $BIN_DIR (default ~/.local/bin).

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROVIDERS_DIR="$ROOT/providers"
TEMPLATE="$ROOT/bin/launcher.template"
BIN_DIR="${BIN_DIR:-${PREFIX:-$HOME/.local}/bin}"

# Pretty output: colors only on a TTY, and never when NO_COLOR is set.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
else
  B=''; DIM=''; GRN=''; YLW=''; CYN=''; RST=''
fi

# ------------------------------------------------------------------ banner

banner() {
  printf '%s\n' \
    "  ${CYN} ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗${RST}" \
    "  ${CYN}██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝${RST}" \
    "  ${CYN}██║     ██║     ███████║██║   ██║██║  ██║█████╗${RST}" \
    "  ${CYN}██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝${RST}" \
    "  ${CYN}╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗${RST}" \
    "  ${CYN} ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝${RST}" \
    "          ${B}C O M P A T I B L E S${RST}" \
    "  ${DIM}run Claude Code on Anthropic-compatible backends${RST}"
  echo
}

# ------------------------------------------------------------------ helpers

discover_providers() {
  local d
  for d in "$PROVIDERS_DIR"/*/; do
    [ -f "$d/.env.example" ] && basename "$d"
  done
  return 0
}

provider_command() { # <provider> -> COMMAND declared in its .env.example
  ( . "$PROVIDERS_DIR/$1/.env.example"; printf '%s' "${COMMAND:-$1}" )
}

api_key_url() { # <provider> -> signup URL from the .env.example comment, if any
  sed -n 's/^#.*get an API key at \(https\?:[^ ]*\).*/\1/p' \
    "$PROVIDERS_DIR/$1/.env.example" | head -1
}

current_token() { # <env file> -> configured token (new or old format), maybe ""
  [ -f "$1" ] || return 0
  local tok
  tok=$(grep -E '^ANTHROPIC_AUTH_TOKEN=' "$1" | head -1 | cut -d= -f2- || true)
  if [ -z "$tok" ]; then
    tok=$(grep -E '^[A-Z_]+_API_KEY=.+' "$1" | head -1 | cut -d= -f2- || true)
  fi
  printf '%s' "$tok"
}

set_token() { # <env file> <token> — rewrite the ANTHROPIC_AUTH_TOKEN= line
  local file=$1 token=$2 tmp line
  tmp=$(mktemp "${file}.XXXXXX")
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in
      ANTHROPIC_AUTH_TOKEN=*) printf 'ANTHROPIC_AUTH_TOKEN=%s\n' "$token" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$file" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$file"
}

ensure_env() { # <provider> — create .env from example; migrate the old layout
  local p=$1 dir env key
  dir="$PROVIDERS_DIR/$p"
  env="$dir/.env"
  if [ ! -f "$env" ]; then
    cp "$dir/.env.example" "$env"
    chmod 600 "$env"
    printf '  %s• created providers/%s/.env from example%s\n' "$DIM" "$p" "$RST"
  elif ! grep -q '^ANTHROPIC_BASE_URL=' "$env"; then
    key=$(current_token "$env")
    mv "$env" "$env.bak"
    cp "$dir/.env.example" "$env"
    chmod 600 "$env"
    if [ -n "$key" ]; then set_token "$env" "$key"; fi
    printf '  %s• migrated old-format providers/%s/.env (backup: .env.bak)%s\n' "$DIM" "$p" "$RST"
  fi
}

# --------------------------------------------------------- checkbox picker

ITEMS=()   # provider names
CHECKED=() # 1/0 per ITEMS index
CURSOR=0
SELECTED=()
OLD_STTY=

cleanup_tty() {
  if [ -n "$OLD_STTY" ]; then
    stty "$OLD_STTY" 2>/dev/null || true
    OLD_STTY=
  fi
  tput cnorm 2>/dev/null || true
}

draw_item() { # <index>
  local i=$1 mark cmd tok
  if [ "${CHECKED[$i]}" = 1 ]; then mark="${GRN}x${RST}"; else mark=' '; fi
  cmd=$(provider_command "${ITEMS[$i]}")
  tok=$(current_token "$PROVIDERS_DIR/${ITEMS[$i]}/.env")
  printf '\033[2K\r'
  if [ "$i" = "$CURSOR" ]; then
    printf '\033[7m> [%s] %-12s\033[0m' "$mark" "${ITEMS[$i]}"
  else
    printf '  [%s] %s%-12s%s' "$mark" "$B" "${ITEMS[$i]}" "$RST"
  fi
  if [ -n "$tok" ]; then
    printf '  %s→ %-10s%s %stoken: set%s\n' "$DIM" "$cmd" "$RST" "$GRN" "$RST"
  else
    printf '  %s→ %-10s%s %stoken: not set%s\n' "$DIM" "$cmd" "$RST" "$DIM" "$RST"
  fi
}

redraw() {
  local i
  printf '\033[%dA' "${#ITEMS[@]}"
  for i in "${!ITEMS[@]}"; do draw_item "$i"; done
}

pick_providers() { # <provider>... -> SELECTED; returns 1 if nothing chosen
  ITEMS=("$@")
  CURSOR=0
  SELECTED=()
  local i key s1 s2 target n=${#ITEMS[@]}

  OLD_STTY=$(stty -g)
  trap cleanup_tty EXIT
  trap 'exit 130' INT TERM
  stty -icanon -echo
  tput civis 2>/dev/null || true

  printf '%sSpace: toggle · a: all · Enter: confirm · Ctrl-C: abort%s\n' "$DIM" "$RST"
  for i in "${!ITEMS[@]}"; do draw_item "$i"; done

  while true; do
    IFS= read -rsn1 key || key=''
    if [ "$key" = "$(printf '\033')" ]; then
      IFS= read -rsn1 -t 1 s1 || s1=''
      IFS= read -rsn1 -t 1 s2 || s2=''
      case $s1$s2 in
        '[A') key=up ;;
        '[B') key=down ;;
        *)    key=ignore ;;
      esac
    fi
    case $key in
      up|k)   if [ "$CURSOR" -gt 0 ]; then CURSOR=$((CURSOR - 1)); fi ;;
      down|j) if [ "$CURSOR" -lt $((n - 1)) ]; then CURSOR=$((CURSOR + 1)); fi ;;
      ' ')    CHECKED[$CURSOR]=$((1 - ${CHECKED[$CURSOR]})) ;;
      a)
        target=0
        for i in "${!ITEMS[@]}"; do
          if [ "${CHECKED[$i]}" = 0 ]; then target=1; fi
        done
        for i in "${!ITEMS[@]}"; do CHECKED[$i]=$target; done
        ;;
      ''|$'\r'|$'\n') break ;;
      *) continue ;;
    esac
    redraw
  done

  cleanup_tty
  trap - EXIT INT TERM

  for i in "${!ITEMS[@]}"; do
    if [ "${CHECKED[$i]}" = 1 ]; then SELECTED+=("${ITEMS[$i]}"); fi
  done
  [ "${#SELECTED[@]}" -gt 0 ]
}

# ------------------------------------------------------------ token prompt

prompt_token() { # <provider>
  local p=$1 env tok url hint new
  env="$PROVIDERS_DIR/$p/.env"
  tok=$(current_token "$env")
  url=$(api_key_url "$p")
  echo
  printf '%s▸ %s%s\n' "$B$CYN" "$p" "$RST"
  if [ -n "$url" ]; then printf '  %sget an API key at %s%s\n' "$DIM" "$url" "$RST"; fi
  if [ -n "$tok" ]; then
    if [ "${#tok}" -gt 4 ]; then hint="****${tok: -4}"; else hint='****'; fi
    printf '  %stoken%s [%s — Enter to keep]: ' "$B" "$RST" "$hint"
  else
    printf '  %stoken%s: ' "$B" "$RST"
  fi
  IFS= read -r new || new=''
  new=$(printf '%s' "$new" | tr -d '[:space:]')
  if [ -z "$new" ]; then
    if [ -n "$tok" ]; then
      printf '  %s✔ kept existing token%s\n' "$GRN" "$RST"
    else
      printf '  %s⚠ left empty — edit providers/%s/.env later%s\n' "$YLW" "$p" "$RST"
    fi
  else
    set_token "$env" "$new"
    printf '  %s✔ token updated%s\n' "$GRN" "$RST"
  fi
}

# ------------------------------------------------------------- installation

install_launcher() { # <provider>
  local p=$1 dir env cmd bin
  dir="$PROVIDERS_DIR/$p"
  env="$dir/.env"
  cmd=$(provider_command "$p")
  sed 's|@@PROVIDER_DIR@@|'"$dir"'|g' "$TEMPLATE" > "$BIN_DIR/$cmd"
  chmod +x "$BIN_DIR/$cmd"
  bin="$BIN_DIR/$cmd"
  if [ -n "${HOME:-}" ]; then case $bin in "$HOME"/*) bin="~/${bin#"$HOME"/}";; esac; fi
  if grep -Eq '^ANTHROPIC_AUTH_TOKEN=.+' "$env"; then
    printf '  %s✔%s %s%s%-10s%s %s%-24s%s %stoken: set%s\n' \
      "$GRN" "$RST" "$B" "$CYN" "$p" "$RST" "$DIM" "$bin" "$RST" "$GRN" "$RST"
  else
    printf '  %s✔%s %s%s%-10s%s %s%-24s%s %stoken: not set — edit providers/%s/.env%s\n' \
      "$GRN" "$RST" "$B" "$CYN" "$p" "$RST" "$DIM" "$bin" "$RST" "$YLW" "$p" "$RST"
  fi
}

check_environment() {
  echo
  if ! command -v claude >/dev/null 2>&1; then
    printf '  %s⚠%s %s\n' "$YLW" "$RST" "'claude' is not on your PATH — install Claude Code first."
  fi
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
      printf '  %s⚠%s %s\n      %s\n' "$YLW" "$RST" \
        "$BIN_DIR is not on your PATH — add to your shell rc:" \
        "export PATH=\"$BIN_DIR:\$PATH\""
      ;;
  esac
}

# -------------------------------------------------------------------- main

main() {
  local providers=() all=() p i tok

  banner

  if [ "$#" -gt 0 ]; then
    providers=("$@")
    for p in "${providers[@]}"; do
      if [ ! -f "$PROVIDERS_DIR/$p/.env.example" ]; then
        echo "setup: unknown provider '$p' (no providers/$p/.env.example)" >&2
        exit 1
      fi
    done
  else
    if [ ! -t 0 ]; then
      echo "setup: the checkbox picker needs an interactive terminal." >&2
      echo "  or name providers directly: bin/setup.sh deepseek glm" >&2
      exit 1
    fi
    while IFS= read -r p; do all+=("$p"); done < <(discover_providers)
    if [ "${#all[@]}" -eq 0 ]; then
      echo "setup: no providers found under $PROVIDERS_DIR" >&2
      exit 1
    fi
    # Pre-check providers that already have a token configured.
    CHECKED=()
    for i in "${!all[@]}"; do
      tok=$(current_token "$PROVIDERS_DIR/${all[$i]}/.env")
      if [ -n "$tok" ]; then CHECKED[$i]=1; else CHECKED[$i]=0; fi
    done
    if ! pick_providers "${all[@]}"; then
      printf '%s⚠ no providers selected — nothing to do%s\n' "$YLW" "$RST"
      exit 0
    fi
    providers=("${SELECTED[@]}")
  fi

  for p in "${providers[@]}"; do
    ensure_env "$p"
    prompt_token "$p"
  done

  echo
  printf '%s▸ installing launchers%s\n' "$B$CYN" "$RST"
  mkdir -p "$BIN_DIR"
  for p in "${providers[@]}"; do
    install_launcher "$p"
  done

  check_environment
}

main "$@"
