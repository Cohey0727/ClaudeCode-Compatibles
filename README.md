# ClaudeCode-Compatibles

> Run Claude Code on Anthropic-compatible LLM backends (DeepSeek · MiniMax · GLM · Kimi) — one repo, one `make setup`, a global command per provider.

One repo that installs global commands to launch [Claude Code](https://docs.anthropic.com/claude-code) against Anthropic-compatible backends:

| Provider | Command   | Endpoint                          | Flagship model |
|----------|-----------|-----------------------------------|----------------|
| DeepSeek | `deepseek`| `https://api.deepseek.com/anthropic` | `deepseek-v4-pro` |
| MiniMax  | `mmxcode` | `https://api.minimax.io/anthropic`   | `MiniMax-M3` |
| GLM (Z.ai) | `glm`   | `https://api.z.ai/api/anthropic`     | `glm-5.2` |
| Kimi (Moonshot) | `kimi` | `https://api.kimi.com/coding` | `kimi-k3[1m]` |

Each provider exposes a native Anthropic-compatible endpoint, so there is no proxy or translation layer — just environment variables.

> **Note:** the MiniMax command is `mmxcode`, not `minimax` or `mmx`, on purpose — both shorter names are already taken and would collide. `minimax` is installed by the official MiniMax Code desktop app (`~/.mavis/bin/minimax`), and `mmx` is an unrelated bun-installed tool (`~/.bun/bin/mmx`).

> **Note:** Kimi has two endpoints. The default `https://api.kimi.com/coding` is for the **coding subscription plan**. For **pay-as-you-go (metered) billing**, switch `ANTHROPIC_BASE_URL` to `https://api.moonshot.ai/anthropic` in `providers/kimi/.env`.

## Layout

```
bin/launcher.template          # generic launcher; @@PROVIDER_DIR@@ baked in at setup time
bin/setup.sh                   # interactive wizard: pick providers, paste tokens, install (`make setup`)
providers/<name>/.env          # all settings: key, endpoint, models (gitignored, chmod 600)
providers/<name>/.env.example  # same file with an empty ANTHROPIC_AUTH_TOKEN (in git)
Makefile                       # setup / uninstall / list
```

Adding a provider is just a new `providers/<name>/` folder with a `.env.example`.

## Requirements

- macOS / Linux with `bash` and `make`
- [Claude Code](https://docs.anthropic.com/claude-code) (`claude` on your PATH)
- An API key for whichever provider(s) you use

## Setup

```bash
make setup
```

One interactive wizard does everything:

1. Check the providers you want (arrows + Space, Enter to confirm — providers that already have a token are pre-checked)
2. Paste each API token — an empty answer keeps the existing token
3. Each provider's `.env` is created from `.env.example` if missing (`chmod 600`)
4. `~/.local/bin/<command>` is generated with the provider folder path baked in
5. You get a warning if `~/.local/bin` or `claude` is missing from your PATH

To rotate a token or add a provider later, just re-run `make setup`.

## Usage

```bash
deepseek          # Claude Code on DeepSeek
mmxcode           # Claude Code on MiniMax
glm               # Claude Code on GLM (Z.ai)
kimi              # Claude Code on Kimi (Moonshot)
```

Arguments pass through to `claude` verbatim:

```bash
glm --help
deepseek -p "Review my TypeScript type definitions"
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

Any extra `KEY=VALUE` lines you add are passed through to `claude` as well.

## How it works

Each installed command is the same thin shell script with one provider folder
path baked in. At runtime it:

1. Sources `providers/<name>/.env` with `set -a` (everything is exported as-is)
2. Fails fast if `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_BASE_URL` is empty
3. `unset`s `COMMAND` / `CLAUDE_ARGS` (launcher metadata) and `ANTHROPIC_API_KEY` (it would otherwise shadow `AUTH_TOKEN`)
4. `exec`s `claude $CLAUDE_ARGS "$@"` — default options first, then your arguments

## Troubleshooting

**`command not found`** — `~/.local/bin` is not on your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
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
