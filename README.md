# ClaudeCode-Compatibles

> Run Claude Code and OpenCode on Anthropic-compatible LLM backends (DeepSeek · MiniMax · GLM · Kimi · MiMo) — one repo, one `make setup`, one `.env` per provider driving both CLIs.

One repo that installs global commands to launch [Claude Code](https://docs.anthropic.com/claude-code) and [OpenCode](https://opencode.ai) against Anthropic-compatible backends:

| Provider | Claude Code | OpenCode | Endpoint                          | Flagship model |
|----------|-------------|----------|-----------------------------------|----------------|
| DeepSeek | `claudedeepseek` | `opendeepseek` | `https://api.deepseek.com/anthropic` | `deepseek-v4-pro` |
| MiniMax  | `claudemmx` | `openmmx` | `https://api.minimax.io/anthropic`   | `MiniMax-M3` |
| GLM (Z.ai) | `claudeglm` | `openglm` | `https://api.z.ai/api/anthropic`     | `glm-5.2` |
| Kimi (Moonshot) | `claudekimi` | `openkimi` | `https://api.kimi.com/coding` | `kimi-k3[1m]` |
| MiMo (Xiaomi) | `claudemimo` | `openmimo` | `https://token-plan-sgp.xiaomimimo.com/anthropic` | `mimo-v2.5-pro[1m]` |

Each provider exposes a native Anthropic-compatible endpoint, so there is no proxy or translation layer — just environment variables. The `open*` commands run OpenCode against the very same endpoint and token: both launchers of a provider share the single `providers/<name>/.env`.

> **Note:** every command follows one naming scheme — `claude<name>` for Claude Code, `open<name>` for OpenCode. Bare provider names are deliberately avoided: `kimi` is Moonshot's official Kimi CLI, `minimax` is the official MiniMax Code desktop app command, and `mmx` is an unrelated bun-installed tool. MiniMax uses the short name `mmx` (`claudemmx` / `openmmx`).

> **Note:** Kimi has two endpoints. The default `https://api.kimi.com/coding` is for the **coding subscription plan**. For **pay-as-you-go (metered) billing**, switch `ANTHROPIC_BASE_URL` to `https://api.moonshot.ai/anthropic` in `providers/kimi/.env`.

> **Note:** MiMo has three endpoints. The default `https://token-plan-sgp.xiaomimimo.com/anthropic` is the **global Token Plan subscription** endpoint (tokens start with `tp-`). China accounts use `https://token-plan-cn.xiaomimimo.com/anthropic` instead, and **pay-as-you-go (metered) billing** (keys start with `sk-`) uses `https://api.xiaomimimo.com/anthropic` — switch `ANTHROPIC_BASE_URL` in `providers/mimo/.env` accordingly. Note the docs mostly mention only the CN host; the `-sgp` host is what actually accepts global-plan tokens.

## Layout

```
bin/launcher.template           # Claude Code launcher; @@PROVIDER_DIR@@ baked in at setup time
bin/opencode-launcher.template  # OpenCode launcher; same .env, generates .opencode.json per launch
bin/setup.sh                    # interactive wizard: pick providers, paste tokens, install (`make setup`)
providers/<name>/.env           # all settings: key, endpoint, models (gitignored, chmod 600)
providers/<name>/.env.example   # same file with an empty ANTHROPIC_AUTH_TOKEN (in git)
providers/<name>/.opencode.json # generated OpenCode config, no secrets (gitignored)
Makefile                        # setup / uninstall / list
```

Adding a provider is just a new `providers/<name>/` folder with a `.env.example`.

## Requirements

- macOS / Linux with `bash` and `make`
- [Claude Code](https://docs.anthropic.com/claude-code) (`claude` on your PATH)
- [OpenCode](https://opencode.ai) (`opencode` on your PATH) — only for the `open*` commands. Not bundled by this repo; install it first:
  ```bash
  brew install sst/tap/opencode          # macOS (Homebrew)
  # or
  npm install -g opencode-ai
  # or
  curl -fsSL https://opencode.ai/install | bash
  ```
- An API key for whichever provider(s) you use

## Setup

```bash
make setup
```

One interactive wizard does everything:

1. Check the providers you want (arrows + Space, Enter to confirm — providers that already have a token are pre-checked)
2. Paste each API token — an empty answer keeps the existing token
3. Each provider's `.env` is created from `.env.example` if missing (`chmod 600`)
4. Two commands per provider are generated in `~/.local/bin` with the provider folder path baked in: the Claude Code launcher (`COMMAND`) and the OpenCode launcher (`OPENCODE_COMMAND`)
5. You get a warning if `~/.local/bin`, `claude` or `opencode` is missing from your PATH

To rotate a token or add a provider later, just re-run `make setup`.

## Usage

```bash
claudedeepseek    # Claude Code on DeepSeek
claudemmx         # Claude Code on MiniMax
claudeglm         # Claude Code on GLM (Z.ai)
claudekimi        # Claude Code on Kimi (Moonshot)
claudemimo        # Claude Code on MiMo (Xiaomi)

opendeepseek      # OpenCode on DeepSeek
openmmx           # OpenCode on MiniMax
openglm           # OpenCode on GLM (Z.ai)
openkimi          # OpenCode on Kimi (Moonshot)
openmimo          # OpenCode on MiMo (Xiaomi)
```

Arguments pass through to `claude` / `opencode` verbatim:

```bash
claudeglm --help
claudedeepseek -p "Review my TypeScript type definitions"
openkimi run "Review my TypeScript type definitions"
```

## `.env` variables

Each provider has exactly one settings file: `providers/<name>/.env`. There is
no mapping layer — every variable uses the name Claude Code itself reads, and
the whole file is exported to `claude` verbatim.

| Variable | Meaning |
|----------|---------|
| `COMMAND` | Installed launcher name (used by `make install`; stripped before `claude` starts) |
| `CLAUDE_ARGS` | Optional default CLI options prepended to every launch (word-split; stripped before `claude` starts). Command-line arguments come after them |
| `ANTHROPIC_AUTH_TOKEN` | **Required.** Your provider API key |
| `ANTHROPIC_BASE_URL` | Provider's Anthropic-compatible endpoint |
| `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` | Model per Claude Code slot |
| `CLAUDE_CODE_SUBAGENT_MODEL`, `CLAUDE_CODE_EFFORT_LEVEL` | Subagent model / effort |
| `API_TIMEOUT_MS`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | Runtime tuning (MiniMax defaults set these) |
| `OPENCODE_COMMAND` | Installed OpenCode launcher name (empty/absent = no OpenCode launcher for this provider) |
| `OPENCODE_ARGS` | Optional default CLI options for the OpenCode launcher (word-split; stripped before `opencode` starts) |
| `OPENCODE_MODEL`, `OPENCODE_SMALL_MODEL` | Model ids OpenCode sends to the API — plain ids, no `[1m]` (that marker is Claude Code-only). Fall back to `ANTHROPIC_MODEL` / `CLAUDE_CODE_SUBAGENT_MODEL` with `[1m]` stripped |

Any extra `KEY=VALUE` lines you add are passed through to `claude` as well.

## How it works

Each installed command is the same thin shell script with one provider folder
path baked in. At runtime it:

1. Sources `providers/<name>/.env` with `set -a` (everything is exported as-is)
2. Fails fast if `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_BASE_URL` is empty
3. `unset`s `COMMAND` / `CLAUDE_ARGS` / `OPENCODE_*` (launcher metadata) and `ANTHROPIC_API_KEY` (it would otherwise shadow `AUTH_TOKEN`)
4. `exec`s `claude $CLAUDE_ARGS "$@"` — default options first, then your arguments

The `open*` commands source the same `.env`, then:

1. Regenerate `providers/<name>/.opencode.json` on every launch, so `.env` stays the single source of truth. It defines a custom `@ai-sdk/anthropic` provider named `<name>-anthropic` with `baseURL` set to `<ANTHROPIC_BASE_URL>/v1` (the AI SDK appends `/messages`, landing on the same `/v1/messages` route Claude Code uses)
2. Keep the token out of that file — it is referenced as `{env:ANTHROPIC_AUTH_TOKEN}` and resolved by OpenCode from the exported environment
3. Point `OPENCODE_CONFIG` at the generated file and `exec opencode $OPENCODE_ARGS "$@"`

OpenCode merges `OPENCODE_CONFIG` between your global `~/.config/opencode/opencode.json` and any project `opencode.json`, so both still apply — the launcher only pins the provider and default models.

## Troubleshooting

**`command not found`** — `~/.local/bin` is not on your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**`'opencode' is not on your PATH — install OpenCode first`** — the `open*` commands launch OpenCode, which this repo does not install. See [Requirements](#requirements):
```bash
brew install sst/tap/opencode   # or: npm install -g opencode-ai
```

**`ANTHROPIC_AUTH_TOKEN is empty`** — re-run `make setup`, or set the key in `providers/<name>/.env` directly.

**Upgrading from the old `config` + `.env` layout** — re-run `make setup`. It
detects an old-format `.env` (no `ANTHROPIC_BASE_URL` line), regenerates it from
`.env.example`, carries your API key over to `ANTHROPIC_AUTH_TOKEN`, and keeps
the original as `.env.bak`.

**You moved the repo** — the baked-in path is stale. Re-run `make setup` from the new location.

## References

- [DeepSeek: Claude Code Integration Guide](https://api-docs.deepseek.com/guides/agent_integrations/claude_code)
- [MiniMax Platform](https://www.minimax.io/platform)
- [Z.ai / GLM Claude Code docs](https://docs.z.ai/devpack/tool/claude)
- [Kimi / Moonshot AI Platform](https://platform.moonshot.ai/docs)
- [Xiaomi MiMo: Claude Code Integration (Token Plan)](https://mimo.mi.com/docs/en-US/tokenplan/integration/claudecode)
- [OpenCode: Config](https://opencode.ai/docs/config/) / [Providers](https://opencode.ai/docs/providers/)
