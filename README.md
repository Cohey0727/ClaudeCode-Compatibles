# ClaudeCode-Compatibles

> Run Claude Code on Anthropic-compatible LLM backends (DeepSeek · MiniMax · GLM) — one repo, one `make install`, a global command per provider.

One repo that installs global commands to launch [Claude Code](https://docs.anthropic.com/claude-code) against Anthropic-compatible backends:

| Provider | Command   | Endpoint                          | Flagship model |
|----------|-----------|-----------------------------------|----------------|
| DeepSeek | `deepseek`| `https://api.deepseek.com/anthropic` | `deepseek-v4-pro` |
| MiniMax  | `minimax` | `https://api.minimax.io/anthropic`   | `MiniMax-M3` |
| GLM (Z.ai) | `glm`   | `https://api.z.ai/api/anthropic`     | `glm-5.2` |

Each provider exposes a native Anthropic-compatible endpoint, so there is no proxy or translation layer — just environment variables.

## Layout

```
bin/launcher.template     # generic launcher; @@PROVIDER_DIR@@ baked in at install time
providers/<name>/config   # non-secret provider definition (command, endpoint, models)
providers/<name>/.env     # your API key + overrides (gitignored, chmod 600)
providers/<name>/.env.example
Makefile                  # install / uninstall / list — all providers or one
```

Adding a provider is just a new `providers/<name>/` folder with a `config` and `.env.example`.

## Requirements

- macOS / Linux with `bash` and `make`
- [Claude Code](https://docs.anthropic.com/claude-code) (`claude` on your PATH)
- An API key for whichever provider(s) you use

## Setup

Install every provider command at once:

```bash
make install
```

Or just one:

```bash
make install PROVIDER=glm
```

`make install`:

1. Creates each provider's `.env` from `.env.example` if missing (`chmod 600`)
2. Generates `~/.local/bin/<command>`, with the absolute path to that provider's folder baked in
3. Reports whether each API key is set, and warns if `~/.local/bin` or `claude` is missing from your PATH

Then fill in the API key in the relevant `providers/<name>/.env` and run the command.

> The DeepSeek and MiniMax `.env` files were carried over from the previous standalone repos, so their keys are already populated. GLM ships without a key — add yours to `providers/glm/.env`.

## Usage

```bash
deepseek          # Claude Code on DeepSeek
minimax           # Claude Code on MiniMax
glm               # Claude Code on GLM (Z.ai)
```

Arguments pass through to `claude` verbatim:

```bash
glm --help
deepseek -p "Review my TypeScript type definitions"
```

## `.env` variables

`<KEY_VAR>` is the only required value. Everything else has a default in
`providers/<name>/config`; uncomment a line in `.env` only to override it.

| Provider | Key variable | Optional overrides |
|----------|--------------|--------------------|
| DeepSeek | `DEEPSEEK_API_KEY` | `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`, `CLAUDE_CODE_EFFORT_LEVEL` |
| MiniMax  | `MINIMAX_API_KEY`  | model slots, `API_TIMEOUT_MS`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW` |
| GLM      | `GLM_API_KEY`      | model slots (`glm-5.2`, `glm-4.5-air`) |

Resolution order for each variable: value in your `.env` (or shell env) > provider default in `config` > unset.

## How it works

Each installed command is the same thin shell script with one provider folder
path baked in. At runtime it:

1. Sources `providers/<name>/config` (endpoint + model defaults)
2. Sources `providers/<name>/.env` (your key + any overrides)
3. Exports `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and the model/runtime variables
4. `unset`s `ANTHROPIC_API_KEY` (it would otherwise shadow `AUTH_TOKEN`)
5. `exec`s `claude "$@"`

## Other targets

```bash
make list                    # show provider -> command -> endpoint
make uninstall               # remove all installed commands (.env files kept)
make uninstall PROVIDER=glm  # remove just one
make install PREFIX=/opt/local   # install under /opt/local/bin instead
```

## Troubleshooting

**`command not found`** — `~/.local/bin` is not on your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**`<KEY_VAR> is empty`** — fill in the key in `providers/<name>/.env`.

**You moved the repo** — the baked-in path is stale. Re-run `make install` from the new location.

## References

- [DeepSeek: Claude Code Integration Guide](https://api-docs.deepseek.com/guides/agent_integrations/claude_code)
- [MiniMax Platform](https://www.minimax.io/platform)
- [Z.ai / GLM Claude Code docs](https://docs.z.ai/devpack/tool/claude)
