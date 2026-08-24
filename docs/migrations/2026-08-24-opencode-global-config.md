# 2026-08-24 — OpenCode ランチャー廃止とグローバル設定生成

`open<name>` ランチャーを廃止した。OpenCode はランチャーなしに素の `opencode`
で使い、`make setup`（および単体の `make opencode-global`）が全プロバイダ
入りの設定を `~/.config/opencode/opencode.json` に生成する。OpenCode 内の
`/models` でどのプロバイダのモデルにも切り替えられる。

生成された設定にトークンは書かれない。各エントリの `apiKey` は `{file:...}`
参照で、同じタイミングで `~/.config/opencode/claude-compatibles/` に書き出さ
れるトークンファイル（chmod 600）を指す。`.env` が引き続き唯一の情報源
ですが、トークンを変更したら再実行してコピーを更新すること。

デフォルトの `model` / `small_model` はトークン設定済みの最初のプロバイダ
（アルファベット順）。変えるには `OPENCODE_DEFAULT_PROVIDER=glm make
opencode-global`。`small_model` は OpenCode の軽量内部処理用で、`/models`
で主モデルを切り替えても変わらない。

`local`（llama.cpp）はプレースホルダトークンが設定されている限りリストに出る。
llama-server が動いていないときに選ぶと、そのリクエストだけが失敗する。

## 手順

```bash
cd <repo>
git pull
make setup                    # .env の追従 + claude/pi ランチャー再生成 + OpenCode 設定生成
rm -f ~/.local/bin/open*      # 旧 open<name> ランチャー（make uninstall でも消える）
```

## 確認

```bash
opencode models               # 全プロバイダの <name>-anthropic モデルが出る
opencode                      # /models で切り替え
```
