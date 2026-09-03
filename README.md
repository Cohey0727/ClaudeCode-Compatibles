# ClaudeCode-Compatibles

> Run Claude Code, OpenCode and pi on Anthropic-compatible LLM backends (DeepSeek · MiniMax · GLM · Kimi · MiMo · OpenRouter · your own llama.cpp) — one repo, one `make setup`, one `.env` per provider driving all three CLIs.

One repo that installs `claude<name>` / `pi<name>` launcher commands and generates an OpenCode config covering every provider — [Claude Code](https://docs.anthropic.com/claude-code), [OpenCode](https://opencode.ai) and the [pi coding agent](https://pi.dev), all against Anthropic-compatible backends:

| Provider | Commands | Endpoint | Flagship model |
|----------|----------|----------|----------------|
| DeepSeek | `claudedeepseek` / `pideepseek` | `https://api.deepseek.com/anthropic` | `deepseek-v4-pro` |
| MiniMax  | `claudemmx` / `pimmx` | `https://api.minimax.io/anthropic` | `MiniMax-M3` |
| GLM (Z.ai) | `claudeglm` / `piglm` | `https://api.z.ai/api/anthropic` | `glm-5.3` |
| Kimi (Moonshot) | `claudekimi` / `pikimi` | `https://api.kimi.com/coding` | `kimi-k3` |
| MiMo (Xiaomi) | `claudemimo` / `pimimo` | `https://token-plan-sgp.xiaomimimo.com/anthropic` | `mimo-v2.5-pro` |
| OpenRouter | `claudeox` / `piox` | `https://openrouter.ai/api` | `stealth/ox-alpha` |
| Local (llama.cpp) | `claudelocal` / `pilocal` | `http://127.0.0.1:11301` | whatever your `llama-server` serves |
| gtr (llama.cpp behind Cloudflare) | `claudegtr` / `pigtr` | `https://gtr-llama.spaghetti-monster.com` | whatever that `llama-server` serves |

OpenCode has no per-provider command: `make setup` writes every provider into OpenCode's global config, so a bare `opencode` gets them all under `/models`.

Kimi and MiMo run that flagship as its 1M-context variant under Claude Code (`kimi-k3[1m]`); OpenCode and pi take the plain id.

Each provider exposes a native Anthropic-compatible endpoint, so there is no proxy or translation layer — just environment variables. That holds for the local one too: `llama-server` answers `/v1/messages` in the Anthropic shape. The `pi*` commands and the generated OpenCode config run against the very same endpoint and token: everything for a provider comes from the single `providers/<name>/.env`.

> **Note:** every launcher command follows one naming scheme — `claude<name>` for Claude Code, `pi<name>` for pi. Bare provider names are deliberately avoided: `kimi` is Moonshot's official Kimi CLI, `minimax` is the official MiniMax Code desktop app command, and `mmx` is an unrelated bun-installed tool. MiniMax uses the short name `mmx` (`claudemmx` / `pimmx`).

> **Note:** Kimi has two endpoints. The default `https://api.kimi.com/coding` is for the **coding subscription plan**. For **pay-as-you-go (metered) billing**, switch `BASE_URL` to `https://api.moonshot.ai/anthropic` in `providers/kimi/.env`.

> **Note:** Local is not a hosted service — it points at a `llama-server` on your own machine, which serves the Anthropic shape on `/v1/messages`. There is no account and no key, so `API_TOKEN` is a placeholder the CLIs merely require to be non-empty. Set `MODEL` to whatever `/v1/models` reports and keep `CONTEXT_WINDOW` at or below the server's `--ctx-size`.

> **Note:** MiMo has three endpoints. The default `https://token-plan-sgp.xiaomimimo.com/anthropic` is the **global Token Plan subscription** endpoint (tokens start with `tp-`). China accounts use `https://token-plan-cn.xiaomimimo.com/anthropic` instead, and **pay-as-you-go (metered) billing** (keys start with `sk-`) uses `https://api.xiaomimimo.com/anthropic` — switch `BASE_URL` in `providers/mimo/.env` accordingly. Note the docs mostly mention only the CN host; the `-sgp` host is what actually accepts global-plan tokens.

> **Note:** OpenRouter is a router rather than a model vendor, and `BASE_URL` is its Anthropic skin — the same `/v1/messages` route, with thinking blocks, tool use and streaming passed through untouched. `MODEL` is therefore any OpenRouter id, vendor prefix and all; the three CLIs split their `<provider>/<model>` reference on the first slash only, so `stealth/ox-alpha` survives intact. The preset is [Ox Alpha](https://openrouter.ai/stealth/ox-alpha): free, 1M context, and run by a provider that stays anonymous for the preview and retains prompts and completions. Stealth models are withdrawn without notice — point `MODEL` in `providers/ox/.env` at another id when it goes.

> **Note:** gtr is a `llama-server` on another machine, published through a Cloudflare tunnel and gated by Cloudflare Access. Requests without Access credentials get a 302 to the login page, so `HEADERS` in `providers/gtr/.env` has to carry an Access service token (`CF-Access-Client-Id` / `CF-Access-Client-Secret`) — the comments in the file show both that and the short-lived `cloudflared access token` variant. Like Local, `API_TOKEN` is only a placeholder unless `llama-server` runs with `--api-key`.

## Layout

```
bin/common.sh                    # shared settings resolution (generic setting <- CLI override)
bin/launcher.template            # Claude Code launcher; @@PROVIDER_DIR@@ baked in at setup time
bin/pi-launcher.template         # pi launcher; same .env, generates .pi-agent/ per launch
bin/pi-global-models.sh          # registers every provider in pi's global models.json (`make pi-global`)
bin/opencode-global-config.sh    # registers every provider in OpenCode's global config (`make opencode-global`)
bin/setup.sh                     # interactive wizard: pick providers, paste tokens, install (`make setup`)
providers/<name>/.env            # all settings: key, endpoint, models (gitignored, chmod 600)
providers/<name>/.env.example    # same file with an empty API_TOKEN (in git)
providers/<name>/.pi-agent/      # generated pi agent dir, no secrets (gitignored)
docs/migrations/                 # upgrade notes for existing checkouts
Makefile                         # setup / uninstall / list / pi-global / opencode-global
```

Adding a provider is just a new `providers/<name>/` folder with a `.env.example`.

## Requirements

- macOS / Linux with `bash` and `make`
- [Claude Code](https://docs.anthropic.com/claude-code) (`claude` on your PATH)
- [OpenCode](https://opencode.ai) (`opencode` on your PATH) — only OpenCode itself; it gets no launcher, just the generated config. Not bundled by this repo; install it first:
  ```bash
  brew install sst/tap/opencode          # macOS (Homebrew)
  # or
  npm install -g opencode-ai
  # or
  curl -fsSL https://opencode.ai/install | bash
  ```
- [pi](https://pi.dev) (`pi` on your PATH) — only for the `pi*` commands. Not bundled by this repo either:
  ```bash
  curl -fsSL https://pi.dev/install.sh | sh
  ```
  (the older `@mariozechner/pi-coding-agent` package is deprecated and resolves environment references differently)
- An API key for whichever provider(s) you use

## Setup

```bash
make setup
```

One interactive wizard does everything:

1. Check the providers you want (arrows + Space, Enter to confirm — providers that already have a token are pre-checked)
2. Paste each API token — an empty answer keeps the existing token
3. Each provider's `.env` is created from `.env.example` if missing (`chmod 600`); an existing `.env` gets any settings that were added to `.env.example` since, appended with their comments and your token untouched
4. Two commands per provider are generated in `~/.local/bin` — `claude<NAME>` and `pi<NAME>`, with the provider folder path baked in
5. The pi packages that add [`/loop` and `/goal`](#loops-in-pi) are installed once into pi's user settings (`~/.pi/agent/settings.json`), shared by every `pi<NAME>`
6. Every provider with a token is registered in OpenCode's global config (`~/.config/opencode/opencode.json`); its token is copied to `~/.config/opencode/claude-compatibles/` (chmod 600) and only referenced from the config
7. You get a warning if `~/.local/bin`, `claude`, `opencode` or `pi` is missing from your PATH

To rotate a token, pick up new settings or add a provider later, just re-run `make setup`.

Coming from an older checkout? `docs/migrations/` has the per-variable
mapping — see [2026-08-15 — pi 対応と `.env` の共通設定化](docs/migrations/2026-08-15-shared-env-settings.md),
[2026-08-15 — GLM-5.3](docs/migrations/2026-08-15-glm-5.3.md)
and [2026-08-24 — OpenCode ランチャー廃止とグローバル設定生成](docs/migrations/2026-08-24-opencode-global-config.md).

### Make targets

| Target | What it does |
|--------|--------------|
| `make setup` | The wizard above: tokens, `.env` upkeep, launcher install, pi packages, OpenCode global config |
| `make list` | Show every provider's commands and endpoint |
| `make pi-global` | Register every provider in `~/.pi/agent/models.json` as well, so a bare `pi` (no launcher) can use them |
| `make opencode-global` | Re-generate OpenCode's global config from the current `.env` files — run it after editing one |
| `make uninstall` | Remove the installed launchers (including legacy `open<name>` ones), the pi packages from `$PI_PACKAGES`, and the global `models.json` / OpenCode config / token files this repo wrote. Provider `.env` files are left alone |

## Usage

```bash
claudedeepseek    # Claude Code on DeepSeek
claudemmx         # Claude Code on MiniMax
claudeglm         # Claude Code on GLM (Z.ai)
claudekimi        # Claude Code on Kimi (Moonshot)
claudemimo        # Claude Code on MiMo (Xiaomi)
claudeox          # Claude Code on OpenRouter (Ox Alpha)
claudegtr         # Claude Code on gtr (llama.cpp behind Cloudflare)

pideepseek        # pi on DeepSeek
pimmx             # pi on MiniMax
piglm             # pi on GLM (Z.ai)
pikimi            # pi on Kimi (Moonshot)
pimimo            # pi on MiMo (Xiaomi)
piox              # pi on OpenRouter (Ox Alpha)
pigtr             # pi on gtr (llama.cpp behind Cloudflare)

opencode          # OpenCode — every configured provider is in /models
```

Arguments pass through to `claude` / `opencode` / `pi` verbatim:

```bash
claudeglm --help
claudedeepseek -p "Review my TypeScript type definitions"
opencode run "Review my TypeScript type definitions"
pimimo -p "Review my TypeScript type definitions"
```

A `--model` you pass yourself wins over the one the `pi*` launcher pins, so you can switch model for a single run:

```bash
pideepseek --model deepseek-anthropic/deepseek-v4-flash
```

OpenCode has no `open<name>` commands. `make setup` (and `make opencode-global`) write every provider that has a token into the global `~/.config/opencode/opencode.json`, so a bare `opencode` starts with all of them and `/models` switches mid-session:

```bash
opencode                                   # starts on the default provider's model
opencode --model glm-anthropic/glm-5.3     # or pick at launch time
```

The default `model` / `small_model` come from the first provider with a token (alphabetical); change it with `OPENCODE_DEFAULT_PROVIDER=glm make opencode-global`. Note `small_model`, which serves OpenCode's lightweight internal calls, stays at that default even after you switch the main model via `/models`.

### Loops in pi

pi keeps its core small and ships no loop of its own — nor sub-agents, MCP,
plan mode or to-dos. Everything of that kind lives in
[pi packages](https://pi.dev/packages), so `make setup` installs two of them
and the `pi<NAME>` commands can iterate unattended the way Claude Code's
`/loop` and `/goal` do:

| Package | Adds | What it does |
|---------|------|--------------|
| [`npm:@realvendex/pi-loop`](https://github.com/ZachDreamZ/pi-loop) | `/loop` | Repeat a prompt until a stop condition: `--max N`, `--until "TEXT"`, `--until-stable N` (convergence), `--timeout 5m`, `--yes` for autopilot |
| `npm:pi-goal` | `/goal` | A persistent objective the agent keeps working on across turns until it is complete, paused, or out of budget |

```
/loop "make the tests pass" --until-stable 2 --max 20
/goal "port the CLI flags to the new parser"
```

They go into pi's user settings, so a bare `pi` gets them too. Install a
different set by overriding `PI_PACKAGES` with `<source>=<slash command>`
pairs — an empty command just leaves the label off:

```bash
PI_PACKAGES="npm:pi-reactor=/reactor npm:pi-loop-police=" make setup
```

> **Note:** pi packages run with full system access and the registry is not
> curated. Both packages above are third-party npm packages — read the source
> before trusting them with an unattended loop, and prefer a container or a
> throwaway checkout for autopilot runs.

## `.env` settings

Each provider has exactly one settings file: `providers/<name>/.env`, and one
set of generic settings in it drives all three CLIs. A provider is roughly ten
lines:

```bash
NAME=deepseek
API_TOKEN=sk-...
BASE_URL=https://api.deepseek.com/anthropic
MODEL=deepseek-v4-pro
SMALL_MODEL=deepseek-v4-flash
CONTEXT_WINDOW=1000000
MAX_TOKENS=384000
REASONING=true
INPUT=text
ARGS=
```

| Setting | Meaning |
|---------|---------|
| `NAME` | Command-name suffix: the launchers are installed as `claude<NAME>` and `pi<NAME>` |
| `API_TOKEN` | **Required.** Your provider API key |
| `BASE_URL` | Provider's Anthropic-compatible endpoint |
| `MODEL` | Fills every main model slot: Claude Code's opus / sonnet / fable, OpenCode's `model` in the generated global config, the model pi starts on |
| `SMALL_MODEL` | Fills every cheap slot: Claude Code's haiku + subagent, OpenCode's `small_model`, pi's second Ctrl+P entry. Defaults to `MODEL` |
| `CONTEXT_WINDOW`, `MAX_TOKENS` | Model limits. pi writes them into its generated `models.json` (it otherwise assumes 128k / 16k and caps each request at `MAX_TOKENS`/3), and Claude Code takes `CONTEXT_WINDOW` as its auto-compact window |
| `SMALL_CONTEXT_WINDOW`, `SMALL_MAX_TOKENS` | The same two limits for `SMALL_MODEL` when it is a different size — GLM sets them for `glm-4.7`. Default to the values above |
| `REASONING`, `INPUT` | Whether the models support extended thinking (`true`/`false`) and what they accept (`text` or `text,image`) |
| `HEADERS` | Optional extra request headers, one `Name: Value` per line (the format Claude Code's `ANTHROPIC_CUSTOM_HEADERS` takes), sent by all three CLIs — e.g. a Cloudflare Access service token in front of a self-hosted server. The value is a bash string, so a multi-line double-quoted value or a `$(...)` computed at launch both work |
| `ARGS` | Default CLI options prepended to every launch, for all three CLIs (word-split; your command-line arguments come after them) |

### Overrides

Every generic setting has a CLI-specific override that wins when set. They all
ship commented out in `.env.example`, with the default they replace written
above them — uncomment one only when a CLI has to differ from the rest.

| Override | Overrides | Read by |
|----------|-----------|---------|
| `COMMAND`, `PI_COMMAND` | the `claude<NAME>` / `pi<NAME>` command names | `make setup` |
| `CLAUDE_ARGS`, `PI_ARGS` | `ARGS` | each launcher |
| `ANTHROPIC_AUTH_TOKEN` | `API_TOKEN` | all three |
| `ANTHROPIC_BASE_URL` | `BASE_URL` | all three |
| `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU,FABLE}_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL` | the model slots Claude Code fills from `MODEL` / `SMALL_MODEL` | Claude Code |
| `OPENCODE_MODEL`, `OPENCODE_SMALL_MODEL` | `MODEL` / `SMALL_MODEL` for OpenCode | the OpenCode global config |
| `PI_MODEL`, `PI_SMALL_MODEL` | `MODEL` / `SMALL_MODEL` for pi | pi |
| `CLAUDE_MODEL_SUFFIX` | nothing — appends a Claude Code-only marker such as `[1m]` to every Claude Code model slot. Kimi and MiMo use it; OpenCode and pi keep sending plain ids | Claude Code |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `CONTEXT_WINDOW` | Claude Code |
| `ANTHROPIC_CUSTOM_HEADERS` | `HEADERS` | Claude Code |

Any extra `KEY=VALUE` line you add is exported to `claude` as well — that is
how `CLAUDE_CODE_EFFORT_LEVEL` and `ENABLE_TOOL_SEARCH` are set. Known
Claude Code-only variables are stripped again before `pi` starts.

## How it works

Each installed command is the same thin shell script with the provider folder
and `bin/common.sh` paths baked in. `common.sh` sources the `.env` (`set -a`,
so extras are exported as-is), resolves the generic settings — override first,
generic second — and fails fast when `API_TOKEN`, `BASE_URL` or `MODEL` is
empty. Then each launcher does its own thing.

`claude<name>` exports the variables Claude Code itself reads:
`ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, the five model slots (each
`MODEL`/`SMALL_MODEL` plus `CLAUDE_MODEL_SUFFIX`) and
`CLAUDE_CODE_AUTO_COMPACT_WINDOW`; drops the launcher-only settings and
`ANTHROPIC_API_KEY` (it would otherwise shadow `AUTH_TOKEN`); and `exec`s
`claude $ARGS "$@"`.

`opencode` gets no launcher. `make setup` (and `make opencode-global`) write
every provider that has a token into the global
`~/.config/opencode/opencode.json` — the same `<name>-anthropic` custom
`@ai-sdk/anthropic` providers, `baseURL` set to `<BASE_URL>/v1` (the AI SDK
appends `/messages`, landing on the same `/v1/messages` route Claude Code
uses), so `/models` lists every provider's `MODEL` and `SMALL_MODEL`. Tokens
stay out of the file: each entry's `apiKey` is a `{file:...}` reference to a
per-provider token file under `~/.config/opencode/claude-compatibles/`
(chmod 600) written from the `.env` at the same time — `.env` stays the single
source of truth, but after rotating a token re-run `make setup` (or
`make opencode-global`) so the copy updates; the re-run also drops token files
of providers whose token was emptied. `HEADERS` values are copied the same
way, one file per header, and referenced from `options.headers`. OpenCode merges `config.json`,
`opencode.json` and `opencode.jsonc` from its config directory (later wins)
and then your project `opencode.json`, so hand-written settings still override
the generated ones — and a file this repo did not generate is never touched
(first-line marker). The `local` provider shows up whenever its placeholder
token is set; picking it while `llama-server` is down fails that one request
and nothing else.

`pi<name>` rebuilds `providers/<name>/.pi-agent/` on every launch and points
`PI_CODING_AGENT_DIR` at it. pi reads `models.json` from its agent directory
only, and that variable moves the whole directory — so everything in
`~/.pi/agent` (settings, auth, skills, prompts, themes, tools) is mirrored
into it as symlinks and only `models.json` is replaced; sessions stay in
`~/.pi/agent/sessions` via `PI_CODING_AGENT_SESSION_DIR`. That `models.json`
holds a `<name>-anthropic` provider with `api: "anthropic-messages"` and
`baseUrl` set to `BASE_URL` as-is (pi hands it to the Anthropic SDK, which
appends `/v1/messages`), plus the two models with their limits. The token
stays out of the file here too: `apiKey` holds the reference
`${ANTHROPIC_AUTH_TOKEN}`, which pi interpolates from the environment at
request time. Finally it `exec`s `pi --model <name>-anthropic/<MODEL> $ARGS
"$@"`.

A bare `pi` (no launcher) has none of that, so it starts with no models at
all. `make pi-global` writes the same provider definitions into
`~/.pi/agent/models.json`, where the token is a `!`-prefixed shell command
that reads it back out of `providers/<name>/.env` — still no secret in the
file, and `.env` stays the single source of truth. Re-run it after changing a
model or endpoint.

Because pi has no subagents, `SMALL_MODEL` is not a slot the agent uses on its
own there — it is just the other entry in the Ctrl+P cycling list
(`--models`).

## Troubleshooting

**`command not found`** — `~/.local/bin` is not on your PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**`'opencode' is not on your PATH — install OpenCode first`** — the generated config is only read by OpenCode itself, which this repo does not install. See [Requirements](#requirements):
```bash
brew install sst/tap/opencode   # or: npm install -g opencode-ai
```

**`opencode` lists none of the providers** — the config is generated, not read live. Run `make opencode-global` (or `make setup`) and check `opencode models`. A token rotated in `.env` also needs the re-run: the config references the copy under `~/.config/opencode/claude-compatibles/`.

**`'pi' is not on your PATH — install the pi coding agent first`** — same story for the `pi*` commands:
```bash
npm install -g @earendil-works/pi-coding-agent   # or: curl -fsSL https://pi.dev/install.sh | sh
```

**pi answers `401 ... Your api key: ****OKEN is invalid`** — the generated
`models.json` refers to the token as `${ANTHROPIC_AUTH_TOKEN}`, which pi 0.8x
interpolates from the environment. The deprecated `@mariozechner` package
(0.73 and older) expects a bare variable name instead and sends the reference
itself as the key. Install `@earendil-works/pi-coding-agent`.

**A bare `pi` says `No models available`** — only the `pi<name>` launchers
configure a provider. Run `make pi-global` to register all of them in
`~/.pi/agent/models.json` as well.

**`API_TOKEN is empty`** — re-run `make setup`, or set the key in `providers/<name>/.env` directly.

**A CLI starts on the wrong model, or pi reports the wrong context size** —
`.env` is the only source. Edit `MODEL` / `CONTEXT_WINDOW` / `MAX_TOKENS`
there, and check whether an override further down the file (`ANTHROPIC_MODEL`,
`OPENCODE_MODEL`, `PI_MODEL`, …) is winning over it.

**An older `.env` still lists every variable** — that keeps working: the old
`ANTHROPIC_*` / `OPENCODE_*` lines are exactly the overrides, so they win over
the generic settings and nothing changes behaviour. Re-run `make setup` to have
the generic settings appended, then delete the override lines you do not need —
or delete the `.env` and re-run `make setup` for a clean one.

**Upgrading from the old `config` + `.env` layout** — re-run `make setup`. It
detects an old-format `.env` (no `BASE_URL` and no `ANTHROPIC_BASE_URL` line),
regenerates it from `.env.example`, carries your API key over, and keeps the
original as `.env.bak`.

**You moved the repo** — the baked-in path is stale. Re-run `make setup` from the new location.

## References

- [DeepSeek: Claude Code Integration Guide](https://api-docs.deepseek.com/guides/agent_integrations/claude_code)
- [MiniMax Platform](https://www.minimax.io/platform)
- [Z.ai / GLM Claude Code docs](https://docs.z.ai/devpack/tool/claude)
- [Kimi / Moonshot AI Platform](https://platform.moonshot.ai/docs)
- [Xiaomi MiMo: Claude Code Integration (Token Plan)](https://mimo.mi.com/docs/en-US/tokenplan/integration/claudecode)
- [OpenRouter: Claude Code Integration](https://openrouter.ai/docs/cookbook/coding-agents/claude-code-integration) / [Ox Alpha](https://openrouter.ai/stealth/ox-alpha)
- [OpenCode: Config](https://opencode.ai/docs/config/) / [Providers](https://opencode.ai/docs/providers/)
- [pi: Custom models](https://pi.dev/docs/latest/models) / [Providers](https://pi.dev/docs/latest/providers) / [DeepSeek's pi integration guide](https://api-docs.deepseek.com/quick_start/agent_integrations/pi_mono/)
