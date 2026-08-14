#!/usr/bin/env bash
# Shared settings resolution for the three launchers, `bin/setup.sh` and the
# Makefile.
#
# A provider's .env holds one set of generic settings (API_TOKEN, BASE_URL,
# MODEL, SMALL_MODEL, ...) that Claude Code, OpenCode and pi all run on.
# Every generic setting has CLI-specific override names that win when set;
# each launcher applies its own after calling load_settings.

pick() { # <var name>... -> value of the first one that is set and non-empty
  local name
  for name in "$@"; do
    if [ -n "${!name:-}" ]; then printf '%s' "${!name}"; return 0; fi
  done
}

launcher_names() { # <provider dir name> -> "claude<name> open<name> pi<name>"
  local suffix="${NAME:-$1}"
  printf '%s %s %s' \
    "${COMMAND:-claude$suffix}" \
    "${OPENCODE_COMMAND:-open$suffix}" \
    "${PI_COMMAND:-pi$suffix}"
}

load_settings() { # <env file> — export it verbatim, then resolve CFG_* from it
  set -a
  # shellcheck disable=SC1090
  source "$1"
  set +a

  CFG_TOKEN=$(pick ANTHROPIC_AUTH_TOKEN API_TOKEN)
  CFG_BASE_URL=$(pick ANTHROPIC_BASE_URL BASE_URL)
  while [[ "$CFG_BASE_URL" == */ ]]; do CFG_BASE_URL="${CFG_BASE_URL%/}"; done

  CFG_ARGS="${ARGS:-}"
  CFG_MODEL="${MODEL:-}"
  CFG_SMALL_MODEL=$(pick SMALL_MODEL MODEL)
  # "[1m]" is a Claude Code-only marker; the other CLIs send ids verbatim.
  CFG_MODEL_PLAIN="${CFG_MODEL%\[1m\]}"
  CFG_SMALL_MODEL_PLAIN="${CFG_SMALL_MODEL%\[1m\]}"

  CFG_CONTEXT_WINDOW="${CONTEXT_WINDOW:-}"
  CFG_MAX_TOKENS="${MAX_TOKENS:-}"
  CFG_SMALL_CONTEXT_WINDOW=$(pick SMALL_CONTEXT_WINDOW CONTEXT_WINDOW)
  CFG_SMALL_MAX_TOKENS=$(pick SMALL_MAX_TOKENS MAX_TOKENS)
  CFG_REASONING="${REASONING:-true}"
  CFG_INPUT="${INPUT:-text}"
}

require_settings() { # <launcher name> <env file> — fail fast on missing basics
  local name=$1 file=$2
  if [ -z "$CFG_TOKEN" ]; then
    echo "$name: API_TOKEN is empty in $file" >&2
    echo "  edit the file and set your API key." >&2
    exit 1
  fi
  if [ -z "$CFG_BASE_URL" ]; then
    echo "$name: BASE_URL is empty in $file" >&2
    exit 1
  fi
  if [ -z "$CFG_MODEL" ]; then
    echo "$name: MODEL is empty in $file" >&2
    exit 1
  fi
}

strip_metadata() { # drop every launcher-only setting from the exported env
  unset NAME API_TOKEN BASE_URL MODEL SMALL_MODEL ARGS
  unset CONTEXT_WINDOW MAX_TOKENS SMALL_CONTEXT_WINDOW SMALL_MAX_TOKENS
  unset REASONING INPUT
  unset COMMAND CLAUDE_ARGS CLAUDE_MODEL_SUFFIX
  unset OPENCODE_COMMAND OPENCODE_ARGS OPENCODE_MODEL OPENCODE_SMALL_MODEL
  unset PI_COMMAND PI_ARGS PI_MODEL PI_SMALL_MODEL
}

strip_claude_env() { # Claude Code-only variables, not for opencode / pi
  unset ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL
  unset ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_FABLE_MODEL
  unset CLAUDE_CODE_SUBAGENT_MODEL CLAUDE_CODE_EFFORT_LEVEL
  unset CLAUDE_CODE_AUTO_COMPACT_WINDOW ENABLE_TOOL_SEARCH
}
