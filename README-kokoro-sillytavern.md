# Kokoro Avatar + SillyTavern Local Setup

この作業ルートは、`kokoro` を「喋るキャラクター表示モジュール」、`SillyTavern` を呼び出し元UIとして使うローカル個人用途の構成です。

## 役割分担

- `kokoro`: `avatar.html` でキャラクター表示、OpenAI互換TTS再生、音量ベース口パク、`postMessage` APIを担当します。
- `SillyTavern`: third-party UI Extensionとしてkokoroのiframeを表示し、AI応答完了時に本文を送信します。
- TTS API key: SillyTavern側では扱いません。kokoro側のURL queryまたはlocalStorageで管理します。

## kokoro側

```powershell
cd kokoro
npm.cmd install
npm.cmd run dev
```

既定のURL:

```text
http://localhost:5173/kokoro/avatar.html
```

動作確認ページ:

```text
http://localhost:5173/kokoro/demo-avatar-controller.html
```

口パク差分画像は以下へ置きます。

```text
kokoro/public/mouth/closed.png
kokoro/public/mouth/half.png
kokoro/public/mouth/open.png
```

キャラクターPNGは既定で `kokoro/public/models/character.png` を見ます。存在しない場合でもアプリは落ちず、生成プレースホルダーで起動します。

## TTS設定

OpenAI互換 `/v1/audio/speech` を使います。例:

```text
http://localhost:5173/kokoro/avatar.html?ttsEndpoint=/irodori-tts&ttsModel=irodori-tts-lite&voice=codex_test_calm_girl&responseFormat=wav
```

利用候補:

- `.\.local-work\Irodori-TTS_v3` 以下のTTSサーバ
  - 起動: `scripts\launch_server.bat`
  - 既定: kokoro dev serverの `/irodori-tts/v1/audio/speech` プロキシ経由で `http://127.0.0.1:8088/v1/audio/speech` へ送信
  - パラメータ: `model=irodori-tts-lite`, `voice=codex_test_calm_girl`, `response_format=wav`
- `.\.local-work\llama.cpp_server` 以下のllama-swap / llama.cpp serverと設定内のggufモデルは、API確認が必要な場合に利用可能

別originのTTSサーバを直接ブラウザから呼ぶため、TTSサーバ側で `http://localhost:5173` などのCORS許可が必要です。

ブラウザのautoplay制限により、初回はavatar iframe内の `Enable Voice` をクリックしてください。TTS生成後に再生だけが拒否された場合は、avatar側の `Play Last Speech` で生成済み音声を再利用できます。

## SillyTavern側

```powershell
cd SillyTavern
npm.cmd install
npm.cmd run start
```

追加した拡張:

```text
SillyTavern/public/scripts/extensions/third-party/kokoro-avatar
```

SillyTavernのExtensionsから `Kokoro Avatar` を有効化し、設定で以下を確認します。

- Enable
- Avatar iframe URL: `http://127.0.0.1:5173/kokoro/avatar.html?ttsEndpoint=/irodori-tts&ttsModel=irodori-tts-lite&voice=codex_test_calm_girl&responseFormat=wav&characterUrl=/kokoro/models/character.png`
- Auto speak on AI response
- Stop current speech before new speech
- iframe width / height
- mouth x / y / scale

### LLM接続設定

`http://127.0.0.1:1234` がOpenAI互換 `/v1/chat/completions` のみを提供する場合は、SillyTavernの `API Connections` で以下にします。

- API: `チャット補完`
- Chat Completion Source: `Custom (OpenAI-compatible)`
- Custom Endpoint URL: `http://127.0.0.1:1234/v1`
- Model ID: `google/gemma-4-e4b`
- Streaming: off
- Show thoughts / reasoning display: off

`テキスト補完` + `llama.cpp` は接続チェックで緑になることがありますが、生成時に `POST /completion` を使うため、OpenAI互換のみのサーバでは `Unexpected endpoint or method. (POST /completion)` になります。

手動確認ボタン:

- `Test Speak`
- `Replay Last`
- `Stop`
- `Reload iframe`

ChatUIでの確認手順:

1. `.\Start-KokoroSillyTavern.ps1` を起動し、`http://127.0.0.1:8000/` を開きます。
2. 右下より少し上の `Kokoro Avatar` パネルが `Avatar: Ready` になるまで待ちます。
3. ブラウザに `Enable Voice` が表示されている場合はクリックします。
4. パネルの `Test` を押し、TTSが鳴るか確認します。
5. ChatUIの入力欄からメッセージを送ります。AI応答が表示されると、Kokoro Avatarへ自動で読み上げ要求が送られます。
6. 読み上げが聞こえなかった場合は、パネルの `Replay` を押します。SillyTavern側で最後に検出したAI応答本文を再度TTSへ送ります。

2026-06-21の確認では、ChatUI送信後に `POST /api/backends/chat-completions/generate` が200、続いて `POST http://127.0.0.1:5173/irodori-tts/v1/audio/speech` が200になりました。追加確認として、`Replay` 未記録時の警告表示、Chat応答後のTTS送信、`Replay` クリック後のTTS再送も確認済みです。

## 一括起動

補助スクリプト:

```powershell
.\Start-KokoroSillyTavern.ps1
```

このスクリプトは既存リポジトリを変更せず、別PowerShellウィンドウでkokoro dev serverとSillyTavernを起動します。

## 検証コマンド

kokoro:

```powershell
npm.cmd run build
```

SillyTavern extension単体Lint:

```powershell
npm.cmd exec -- eslint public/scripts/extensions/third-party/kokoro-avatar/index.js
```

## postMessage概要

SillyTavern拡張はiframeへ以下を送ります。

```js
{ type: "kokoro:speak", text: "読み上げる文章" }
{ type: "kokoro:stop" }
{ type: "kokoro:setMouthConfig", config: { x: 500, y: 520, scale: 1 } }
```

詳細は `kokoro/docs/avatar-integration.md` と `SillyTavern/public/scripts/extensions/third-party/kokoro-avatar/README.md` を参照してください。
