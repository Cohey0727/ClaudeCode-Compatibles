# 2026-09-05 — OpenCode の lean エージェント

OpenCode が gtr に送る 1 リクエストの固定部分が大きすぎて、llama-server の
prefill が数分単位になっていた。`providers/<name>/.env` に `OPENCODE_LEAN=true`
を書くと、そのプロバイダ専用の agent が `~/.config/opencode/opencode.json` に
生成され、固定部分が縮む。gtr は既定で有効。

gtr サーバーの `/tokenize` で実測した `opencode run "hi"` 1 発の入力トークン数:

| | 合計 | system | tools |
|---|---|---|---|
| 変更前 | 9,951 | 5,104 | 5,032（10 個） |
| 変更後 | 4,126 | 1,160 | 3,048（6 個） |

内訳:

- `prompt` に `bin/opencode-lean-prompt.md` のコピーを指定する。これは
  OpenCode のモデル別ベースプロンプトを**置き換える**（追記ではない）。
- `skill` を deny すると `<available_skills>` ブロックが丸ごと消える。ここだけ
  で 2,344 トークンあった。
- `task` / `todowrite` / `webfetch` も deny し、残るのは `bash` `edit` `read`
  `write` `grep` `glob` の 6 つ。

deny したツールは定義ごとリクエストから消えるが、**OpenCode が登録していない
名前を deny すると `edit` と `write` まで一緒に落ちる**。`apply_patch` や
`todoread` のような docs にしかない名前を足さないこと。無効化リストは
`bin/common.sh` の `OPENCODE_LEAN_DISABLED_TOOLS` にある。

あわせて、生成される provider ブロックが全プロバイダで
`models.<id>.limit.{context,output}` を持つようになった。これまで `{}` で、
OpenCode 側にコンテキスト長の情報がなかった。gtr は
`OPENCODE_CONTEXT_WINDOW=16384` / `OPENCODE_MAX_TOKENS=4096` で、サーバーの
`--ctx-size`（262144）ではなく「prefill が現実的な時間で終わる長さ」を渡す。
セッションがここに達すると OpenCode が compaction する。

`opencode` は、lean なプロバイダが `DEFAULT_PROVIDER` でもあるとき、その agent
で起動する（`default_agent`）。Tab で素の `build` に切り替わる。AGENTS.md /
CLAUDE.md はどちらの agent でも読まれる。

## 手順

```bash
cd <repo>
git pull
make setup            # または make opencode-global だけでもよい
```

## 確認

```bash
opencode run "hi"     # ヘッダが "> gtr · default" になる
```

`~/.config/opencode/opencode.json` に `"agent": { "gtr": ... }` と
`"default_agent": "gtr"` があること。

## 元に戻す

`providers/gtr/.env` の `OPENCODE_LEAN` を `false` にして
`make opencode-global`。
