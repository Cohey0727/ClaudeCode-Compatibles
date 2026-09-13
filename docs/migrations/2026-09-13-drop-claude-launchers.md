# 2026-09-13 — Claude Code ランチャー廃止と見出し・API 別の configs.jsonc

Claude Code 用の `claude<name>` ランチャーをやめた。provider が Anthropic 互換で
ある必要がなくなったので、configs.jsonc で provider ごと・モデルごとに API を
選べるようにし、OpenCode のモデル選択の見出しも configs.jsonc で決めるようにした。

```
OpenCode Zen          OpenCode のサービス。/connect で入れる
Command Code          providers."Command Code"
  claude-opus-5
  deepseek/deepseek-v4.1-flash
  ...
OpenCode Go           OpenCode のサービス。/connect で入れる
Subscriptions         providers.Subscriptions
  DeepSeek deepseek-v4-pro
  Z.AI glm-5.3
  ...
```

変更点:

- `providers` の 1 段下が見出しになった。その下に provider を置く。
  provider 名は見出しをまたいで一意。

  ```jsonc
  "providers": {
    "Subscriptions": { "deepseek": { … }, "glm": { … } },
    "Command Code": { "commandcode": { … } }
  }
  ```

- provider に `api` を必須で書く。`"anthropic"`（`<BASE_URL>/v1/messages`）か
  `"openai"`（`<BASE_URL>/v1/chat/completions`）。モデルごとに上書きできる。
  `BASE_URL` の形は変わらない。
- 削除したキー: provider の `claude`（`command` / `args` / `env` /
  `auto_compact_window`）、モデルの `claude_id`、タグ
  `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` /
  `ANTHROPIC_DEFAULT_FABLE_MODEL` / `CLAUDE_CODE_SUBAGENT_MODEL`。
  タグは `default` / `small` だけ。
- `label` は省略できる。省略すると OpenCode のモデル名は id だけになる。
- Command Code を `opencode.overrides.provider` から `providers."Command Code"`
  に移した。キーは `.env` の `COMMAND_CODE_API_KEY`。
- 生成される設定の provider id が、全 CLI で `<name>-<api>` になった。
  OpenCode / Crush / Codewhale / DeepSeek Harness は元から `<name>-anthropic`
  なので変わらない。pi と Reasonix は provider 名そのままだったのが変わる。

| CLI | 変更前 | 変更後 |
|---|---|---|
| pi | `glm/glm-5.3` | `glm-anthropic/glm-5.3` |
| Reasonix | `glm/glm-5.3` | `glm-anthropic/glm-5.3` |

## 手順

```bash
cd <repo>
git pull
rm -f ~/.local/bin/claude{deepseek,glm,kimi,local,gtr}
make setup
```

`rm` の対象はこのレポが入れたランチャーだけ。`~/.local/bin/claude`（Claude Code
本体）は消さない。`command` を変えていた provider は、その名前で消す。

手で書いた configs.jsonc の provider は、見出しの下に移し、`api` を足し、
`claude` / `claude_id` と Claude Code 用のタグを消す。`make check` が残りを
指摘する。

## 確認

```bash
make check
opencode models | grep -- '-anthropic/\|-openai/'
```

`/models` で、configs.jsonc の見出しごとにモデルが並んでいること。
