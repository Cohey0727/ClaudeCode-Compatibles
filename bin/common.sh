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

pi_resolve() { # after load_settings: pi's view of the settings, overrides applied
  PI_CFG_MODEL="${PI_MODEL:-$CFG_MODEL_PLAIN}"
  PI_CFG_MODEL="${PI_CFG_MODEL%\[1m\]}"
  PI_CFG_SMALL_MODEL="${PI_SMALL_MODEL:-$CFG_SMALL_MODEL_PLAIN}"
  PI_CFG_SMALL_MODEL="${PI_CFG_SMALL_MODEL%\[1m\]}"

  # pi assumes 128k context / 16k output for models it does not know and caps
  # each request at maxTokens/3, so both limits are always written out.
  PI_CFG_CONTEXT_WINDOW="${CFG_CONTEXT_WINDOW:-200000}"
  PI_CFG_MAX_TOKENS="${CFG_MAX_TOKENS:-32768}"
  PI_CFG_SMALL_CONTEXT_WINDOW="${CFG_SMALL_CONTEXT_WINDOW:-$PI_CFG_CONTEXT_WINDOW}"
  PI_CFG_SMALL_MAX_TOKENS="${CFG_SMALL_MAX_TOKENS:-$PI_CFG_MAX_TOKENS}"

  if [ "$CFG_REASONING" = "true" ]; then PI_CFG_REASONING=true; else PI_CFG_REASONING=false; fi
  case ",$CFG_INPUT," in
    *,image,*) PI_CFG_INPUT='["text", "image"]' ;;
    *)         PI_CFG_INPUT='["text"]' ;;
  esac
}

pi_provider_json() { # <provider id> <apiKey reference> — one models.json provider block
  local id=$1 api_key=$2 models
  models=$(pi_model_json "$PI_CFG_MODEL" "$PI_CFG_CONTEXT_WINDOW" "$PI_CFG_MAX_TOKENS")
  if [ "$PI_CFG_SMALL_MODEL" != "$PI_CFG_MODEL" ]; then
    models="$models,
$(pi_model_json "$PI_CFG_SMALL_MODEL" "$PI_CFG_SMALL_CONTEXT_WINDOW" "$PI_CFG_SMALL_MAX_TOKENS")"
  fi
  cat <<EOF
    "$id": {
      "baseUrl": "$CFG_BASE_URL",
      "api": "anthropic-messages",
      "apiKey": "$api_key",
      "models": [
$models
      ]
    }
EOF
}

pi_model_json() { # <model id> <context window> <max tokens>
  cat <<EOF
        {
          "id": "$1",
          "reasoning": $PI_CFG_REASONING,
          "input": $PI_CFG_INPUT,
          "contextWindow": $2,
          "maxTokens": $3
        }
EOF
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
