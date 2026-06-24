# EasyCharacterChatWebUI

`kokoro` のアバター表示と `SillyTavern` のChat UIをつないで、ローカル環境でキャラクター表示、読み上げ、口パクをまとめて動かすためのワークスペースです。

このリポジトリ自体は親repoで、実装本体は次のsubmoduleを参照します。

- `kokoro`
- `SillyTavern`

両submoduleは `.gitmodules` で `EasyCharacterChatWebUI` ブランチを追う設定にしてあります。

## License

この親repoは Apache License 2.0 です。詳細は [LICENSE](LICENSE) を参照してください。

## 構成

- `kokoro`: `avatar.html`、OpenAI互換TTS呼び出し、音量ベース口パク、アバター表示
- `SillyTavern`: Chat UI、`kokoro-avatar` 拡張、アバターiframeへの `postMessage` 転送
- `Start-KokoroSillyTavern.ps1`: `kokoro` dev server と `SillyTavern` を別PowerShellで起動

## 前提

- Windows + PowerShell
- Node.js / npm
- LLMサーバ
  - `http://127.0.0.1:1234`
  - model: `google/gemma-4-e4b`
- TTSサーバ
  - `http://127.0.0.1:8088`
  - 例: `.\.local-work\Irodori-TTS_v3\scripts\launch_server.bat`

## セットアップ

submodule込みで取得する場合:

```powershell
git clone --recurse-submodules https://github.com/Kitagawa65536/EasyCharacterChatWebUI.git
cd EasyCharacterChatWebUI
git submodule update --init --recursive
```

既にclone済みの場合:

```powershell
git submodule update --init --recursive
```

依存関係のインストール:

```powershell
cd kokoro
npm.cmd install

cd ..\SillyTavern
npm.cmd install
```

## 起動手順

LLMサーバとTTSサーバを先に起動してから、親repoで次を実行します。

```powershell
cd .
.\Start-KokoroSillyTavern.ps1
```

このスクリプトは次を起動します。

- `kokoro`: `http://127.0.0.1:5173/kokoro/avatar.html`
- `SillyTavern`: `http://127.0.0.1:8000/`

手動で起動する場合:

```powershell
cd kokoro
npm.cmd run dev -- --host 127.0.0.1 --port 5173
```

```powershell
cd SillyTavern
npm.cmd run start
```

## SillyTavern設定

SillyTavernの Extensions で `Kokoro Avatar` を有効化し、次を確認します。

- `Enable`
- `Auto speak on AI response`
- `Stop current speech before new speech`
- `Avatar iframe URL`

既定の `Avatar iframe URL`:

```text
http://127.0.0.1:5173/kokoro/avatar.html?ttsEndpoint=/irodori-tts&ttsModel=irodori-tts&voice=codex_test_calm_girl&responseFormat=wav&characterUrl=/kokoro/models/character.png
```

LLM接続は OpenAI互換 Chat Completions 前提です。

- API: `チャット補完`
- Chat Completion Source: `Custom (OpenAI-compatible)`
- Custom Endpoint URL: `http://127.0.0.1:1234/v1`
- Model ID: `google/gemma-4-e4b`
- Streaming: off
- Show thoughts / reasoning display: off

## 動作確認

1. `http://127.0.0.1:8000/` を開きます。
2. `Kokoro Avatar` パネルが `Avatar: Ready` になるまで待ちます。
3. 初回はアバターiframe内の `Enable Voice` をクリックします。
4. パネルの `Test` を押してTTSが鳴ることを確認します。
5. Chat UIからメッセージを送ります。
6. 読み上げが聞こえなかった場合はパネルの `Replay` を押します。

## 注意点

- ブラウザのautoplay制限:
  初回は `Enable Voice` が必要です。音声生成は成功しても再生だけ止まることがあります。その場合はアバター側の `Play Last Speech` で再生だけやり直せます。

- TTSのクロスオリジン:
  `kokoro` から別originのTTSサーバへ直接fetchする場合、TTSサーバ側で `http://127.0.0.1:5173` または `http://localhost:5173` を許可する CORS 設定が必要です。許可が足りないとブラウザ側で弾かれます。

- TTS proxy利用時の前提:
  既定設定では `kokoro` dev server の `/irodori-tts` プロキシ経由で `http://127.0.0.1:8088/v1/audio/speech` に送ります。`avatar.html` の `ttsEndpoint=/irodori-tts` を変えた場合は、CORS条件も一緒に見直してください。

- LLM API種別の違い:
  `http://127.0.0.1:1234` が OpenAI互換 `/v1/chat/completions` のみなら、SillyTavern の `テキスト補完` + `llama.cpp` は使わないでください。生成時に `POST /completion` へ行って失敗します。

- Gemma系の推論表示:
  reasoning表示を有効にすると出力枠を食いやすいので、`show_thoughts=false` と十分な `max_tokens` を維持するのが安定です。

- 口差分画像:
  `kokoro/public/mouth/closed.png`, `half.png`, `open.png` を差し替える場合は、同じキャンバスサイズで揃えると位置調整が崩れにくいです。

## 参考

- 詳細セットアップ: [README-kokoro-sillytavern.md](README-kokoro-sillytavern.md)
- 引き継ぎ: [HANDOFF.md](HANDOFF.md)
