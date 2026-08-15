# 2026-08-15 — pi 対応と `.env` の共通設定化

pi (pi coding agent) が 3 つ目の CLI として加わり、それに合わせて
`providers/<name>/.env` を Claude Code / OpenCode / pi の共通設定に作り直した。
既存マシンで作業するときの手順をここにまとめる。

対象コミット: `14ae029` (共通設定化) / `1a4caef` (pi 0.8x の apiKey 修正) /
`484c78f` (make ターゲット整理)

## 何もしなくても壊れはしない

旧 `.env` の `ANTHROPIC_*` / `OPENCODE_*` はすべて **上書き設定** として今も有効で、
優先度は共通設定より高い。つまり旧 `.env` のままでも Claude Code と OpenCode は
従来通り動く。ただし次の 2 点は移行しないと得られない:

- pi (`pi<name>` コマンド) が使う `CONTEXT_WINDOW` / `MAX_TOKENS` / `REASONING` /
  `INPUT`。無いと 200k / 32k の保守的な既定値になる
- Claude Code の `CLAUDE_CODE_AUTO_COMPACT_WINDOW` の自動導出

## 手順

```bash
cd <repo>
git pull

# 1. pi を入れる（pi* コマンドを使う場合のみ）
npm install -g @earendil-works/pi-coding-agent
#   または curl -fsSL https://pi.dev/install.sh | sh

# 2. .env を新形式に書き換える（下の対応表）

# 3. ランチャーを再生成する（15 コマンド: claude* / open* / pi*）
make setup

# 4. 確認
make list
```

`make setup` は `.env.example` に増えた設定を既存 `.env` に追記するだけで、
旧い行は消さない。**旧い行が残っていると上書きとして勝ち続ける**ので、
きれいにしたいなら下の対応表どおりに手で置き換えるか、`.env` を消して
`make setup` で作り直し、トークンを貼り直すのが早い。

## 環境変数の対応表

| 旧 `.env` | 新 `.env` | メモ |
|---|---|---|
| `COMMAND=claudedeepseek` | `NAME=deepseek` | `claude<NAME>` / `open<NAME>` / `pi<NAME>` を自動生成 |
| `OPENCODE_COMMAND=opendeepseek` | 削除 | 同上。個別に変えたいときだけ `OPENCODE_COMMAND` を残す |
| `ANTHROPIC_AUTH_TOKEN=sk-...` | `API_TOKEN=sk-...` | 旧名のままでも動く（上書き扱い） |
| `ANTHROPIC_BASE_URL=...` | `BASE_URL=...` | 同上 |
| `ANTHROPIC_MODEL`<br>`ANTHROPIC_DEFAULT_OPUS_MODEL`<br>`ANTHROPIC_DEFAULT_SONNET_MODEL`<br>`ANTHROPIC_DEFAULT_FABLE_MODEL`<br>`OPENCODE_MODEL` | `MODEL=` | 5 行 → 1 行。opus / sonnet / fable は `ANTHROPIC_MODEL` に追従する |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL`<br>`CLAUDE_CODE_SUBAGENT_MODEL`<br>`OPENCODE_SMALL_MODEL` | `SMALL_MODEL=` | 3 行 → 1 行 |
| モデル id 中の `[1m]` (kimi / mimo) | `CLAUDE_MODEL_SUFFIX=[1m]` | Claude Code の全スロットにだけ付く。OpenCode と pi は素の id |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW=1048576` | `CONTEXT_WINDOW=1048576` | Claude Code の auto-compact はここから導出 |
| (新規) | `MAX_TOKENS=` | pi の `models.json` に書く出力上限。pi は 1 リクエストを `MAX_TOKENS`/3 で頭打ちにする |
| (新規) | `REASONING=` / `INPUT=` | pi 用。`true`/`false`、`text` か `text,image` |
| (新規・必要時) | `SMALL_CONTEXT_WINDOW=` / `SMALL_MAX_TOKENS=` | `SMALL_MODEL` が別サイズのときだけ（GLM のみ） |
| `CLAUDE_ARGS=` | `ARGS=` | 3 CLI 共通。CLI 別にしたいなら `CLAUDE_ARGS` / `OPENCODE_ARGS` / `PI_ARGS` |
| `CLAUDE_CODE_EFFORT_LEVEL`<br>`ENABLE_TOOL_SEARCH` | そのまま | Claude Code 固有の追加設定はそのまま渡る（pi / OpenCode には渡さない） |

## 移行後の `.env`（プロバイダ別の値）

`API_TOKEN` 以外は `.env.example` と同じ。トークンだけ各マシンで入れる。

| 設定 | deepseek | glm | kimi | mimo | minimax |
|---|---|---|---|---|---|
| `NAME` | `deepseek` | `glm` | `kimi` | `mimo` | `mmx` |
| `BASE_URL` | `https://api.deepseek.com/anthropic` | `https://api.z.ai/api/anthropic` | `https://api.kimi.com/coding` | `https://token-plan-sgp.xiaomimimo.com/anthropic` | `https://api.minimax.io/anthropic` |
| `MODEL` | `deepseek-v4-pro` | `glm-5.3` | `kimi-k3` | `mimo-v2.5-pro` | `MiniMax-M3` |
| `SMALL_MODEL` | `deepseek-v4-flash` | `glm-4.7` | `kimi-k3` | `mimo-v2.5-pro` | `MiniMax-M3` |
| `CONTEXT_WINDOW` | `1000000` | `1000000` | `1048576` | `1048576` | `1000000` |
| `MAX_TOKENS` | `384000` | `131072` | `131072` | `131072` | `128000` |
| `REASONING` | `true` | `true` | `true` | `true` | `true` |
| `INPUT` | `text` | `text` | `text,image` | `text` | `text,image` |
| `CLAUDE_MODEL_SUFFIX` | — | — | `[1m]` | `[1m]` | — |
| その他 | `CLAUDE_CODE_EFFORT_LEVEL=max` | 左に加えて `SMALL_CONTEXT_WINDOW=200000` / `SMALL_MAX_TOKENS=131072` | 左に加えて `ENABLE_TOOL_SEARCH=false` | 左に加えて `ENABLE_TOOL_SEARCH=false` | `CLAUDE_CODE_EFFORT_LEVEL=max` |

deepseek の移行例:

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
CLAUDE_CODE_EFFORT_LEVEL=max
```

## 確認

```bash
make list                       # 15 コマンドと endpoint が並ぶ
pideepseek --list-models        # deepseek-anthropic のモデルと上限が出る
pideepseek -p "say ok"          # 実リクエスト
claudedeepseek --version        # Claude Code 側も起動するか
```

## 落とし穴

**`401 ... Your api key: ****OKEN is invalid`**
pi のパッケージが古い。`@mariozechner/pi-coding-agent` (0.73 以前・deprecated) は
`models.json` の `apiKey` を裸の変数名で解決するが、現行の
`@earendil-works/pi-coding-agent` (0.8x) は `${VAR}` 展開なので、参照文字列が
そのままキーとして送られる。現行パッケージを入れ直す。

**bare `pi` で `No models available`**
`pi<name>` ランチャーだけがプロバイダを設定する。素の `pi` でも使いたいなら
`make pi-global` で `~/.pi/agent/models.json` に全プロバイダを登録する
（トークンはファイルに入らず、`.env` を読むシェルコマンドが入る）。

**古いランチャーが残る**
`make setup` のチェックボックスで選ばなかったプロバイダは、古いテンプレートの
ままの `claude*` / `open*` が `~/.local/bin` に残り、新形式の `.env` を読めずに
`ANTHROPIC_AUTH_TOKEN is empty` で落ちる。全プロバイダを選び直すか
`bin/setup.sh <provider>` で個別に再生成する。

**tmux で `extended-keys is off` の警告**
pi の起動チェック。tmux 3.5 以降なら `~/.tmux.conf` に足して
`tmux source-file ~/.tmux.conf`:

```
set -g extended-keys on
set -g extended-keys-format csi-u
```
