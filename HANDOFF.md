# 引き継ぎ資料: Kokoro 口パク連携

## プロジェクトの概要

このプロジェクトは、`kokoro` 側の喋るAvatarモジュールと、`SillyTavern` 側の拡張をつないで、ローカル環境だけで口パク付きのキャラクター表示と読み上げを動かすための実装です。

構成は大きく2つです。

- `kokoro`: Avatar本体、TTS、音量ベース口パク、画像表示
- `SillyTavern`: チャットイベントを拾って `postMessage` で Avatar に読み上げ指示を送る拡張

現在の中心は「状態を持つのは Repository と UI 表層だけ、処理単体はなるべくステートレスにする」方針です。設定は `AvatarSettingsRepository` と `extension_settings` に寄せ、読み上げや口パクの実行ロジックは小さい責務に分割しています。

## 現在実装済みの範囲

### `kokoro` 側

- `avatar.html` で Avatar を表示
- `postMessage` で以下を受信
  - `kokoro:speak`
  - `kokoro:stop`
  - `kokoro:setExpression`
  - `kokoro:setMouthConfig`
- OpenAI互換の TTS 呼び出し
- 音声再生とブラウザ autoplay 制限への対応
  - `Enable Voice`
  - `Play Last Speech`
- 音量ベースの口パク
- 深度推定による視差っぽい追従
- マウス追従に時間ベースの常時揺れを合成
- 口差分スプライトの位置も深度視差の `Pose` に追従
- 口差分素材を `kokoro/public/mouth/*.png` に配置済み
  - `closed.png`
  - `half.png`
  - `open.png`
  - 口の上下左右に余白を持たせて、接合部に顔の輪郭線が出にくい版にしてある
- 添付画像を既定キャラ画像として追加
  - `kokoro/public/models/character.png`
- 口差分の置き場所を用意
  - `kokoro/public/mouth/README.md`

### `SillyTavern` 側

- third-party extension `kokoro-avatar` を追加
- チャットのキャラクターメッセージを拾って読み上げ指示を送る
- 右下固定の Avatar パネルを表示
- パネル上に常時表示の操作バーを追加
  - `Test`
  - `Replay`
  - `Stop`
  - `Reload`
- 直近AI応答本文を再度TTSへ送る `Replay` / `Replay Last` を追加
- `Avatar: Ready` まで待ってから送る簡易キューを追加
- Avatar 側からの状態通知を受けてパネル表示へ反映
- 既定 URL を `127.0.0.1` ベースに統一
- 既定キャラ画像 URL を `characterUrl=/kokoro/models/character.png` に統一
- 現ユーザー設定をOpenAI互換Chat Completions向けに更新済み
  - `main_api=openai`
  - `chat_completion_source=custom`
  - `custom_url=http://127.0.0.1:1234/v1`
  - `custom_model=google/gemma-4-e4b`
  - `stream_openai=false`
  - `show_thoughts=false`
- `Kokoro Avatar` パネルを入力欄より上に移動し、送信ボタンを塞がないように調整済み

### 直近のコミット

- 親repo: `Add Apache 2.0 license and startup README`
- 親repo: `Initialize EasyCharacterChatWebUI workspace`
- `kokoro`: `6eddfd1 Sync mouth overlay with avatar motion`
- `kokoro`: `97bf629 Add mouth sprite assets`
- `kokoro`: `7b7d3bb Use provided avatar image`
- `SillyTavern`: `650b0823f Add Kokoro avatar replay control`
- `SillyTavern`: `ce71ff8df Add visible Kokoro avatar panel controls`

## ここまでの設計判断などの実装に関する注意点

- 状態はできるだけ分離しています。TTS 設定は `AvatarSettingsRepository`、口設定は `MouthConfig`、表示は `AvatarView`、受信は `AvatarMessageController` に分けています。
- `kokoro` は「表示・音声・口パク」だけを担当し、チャット履歴や会話ロジックは持ちません。
- `SillyTavern` 側は「イベント収集と転送」に徹し、TTS API key は持たせていません。
- 画像パスは `vite.config.ts` の `base: "/kokoro/"` 前提です。既定パスは `/kokoro/models/character.png` と `/kokoro/mouth/*.png` です。
- 口差分がまだない場合でも落ちないように、口とキャラはフォールバック描画で継続動作します。
- 高解像度の添付キャラ画像は初期化に少し時間がかかるため、`SillyTavern` 側では `Avatar: Ready` 前の `Test` をキューする実装にしています。
- ブラウザの autoplay 制限があるので、初回再生は `Enable Voice` が必要です。これは不具合ではなくブラウザ側の制約です。
- 右下の表示が見えづらいときは、パネル上部の `Test / Replay / Stop / Reload` を使ってまず状態を切り分けます。
- `http://127.0.0.1:1234` がOpenAI互換のみの場合、SillyTavernの `テキスト補完` + `llama.cpp` は避けます。接続チェックは緑でも、生成時に `POST /completion` へ投げて `Unexpected endpoint or method. (POST /completion)` になります。
- OpenAI互換Chat Completionsでは、Gemma系が推論欄だけで出力枠を使い切ることがあります。`show_thoughts=false` と十分な `openai_max_tokens` を維持してください。
- 口位置の初期値は、添付画像 `2304x3072` の座標でおおよそ `x=1152`, `y=1385` を使っています。差分PNGを作るときはこの位置を基準にしてください。
- 口差分の最終配置は `380x150` で、上下左右に少し広めの余白を残しています。輪郭線が見える場合は、まず `MouthConfig.scale` より素材の余白側を見直します。
- `kokoro/src/avatar/avatar-view.ts` は、マウス追従の `pointer` に常時揺れを足した `Pose` をキャラ本体と口差分スプライトへ同じように適用します。この変更は `6eddfd1` でコミット済みです。現在は目視調整用に `IDLE_SWAY_X=0.14` / `IDLE_SWAY_Y=0.09` へ未コミットで大きめにしています。
- 音声連携ログは、`kokoro` のVite dev serverが `POST /kokoro/__audio-log` を受けて `kokoro/logs/audio-linkage.log` にJSON Linesで追記します。`logs` はignore対象です。
- 2026-06-25の音声不通調査では、`avatar.init.error` が出て `avatar.speak.request` / `tts.request.start` が出ていなかったため、TTS以前にAvatar初期化が止まっていました。深度推定失敗時は `avatar.depth.fallback` を出してフォールバックPoseでReadyまで進むように未コミット修正済みです。
- 2026-06-25のTTS 400調査では、TTSサーバが `irodori-tts-lite` のみを返しているのに、Avatar URL が `ttsModel=irodori-tts` のままだったため `Unsupported model 'irodori-tts'. Use 'irodori-tts-lite'.` になっていました。既定URL、現ユーザー設定、README類は `irodori-tts-lite` へ未コミット修正済みです。
- `.local-work` のjunctionはTTS/LLM参照用で、`kokoro` 本体・`kokoro/public/models/character.png`・深度推定モデルの直接パスではありません。深度失敗の直接原因としては低めですが、TTSサーバ起動側の切り分けでは引き続き注意します。
- 深度推定が失敗すると `AvatarView.init()` が `this.app.ticker.add(() => this.tick())` まで到達しないため、時間ベースの揺れが見えない原因にもなります。現在は深度Workerエラーを詳細化し、失敗してもフォールバックでticker登録まで進める方針です。
- `SillyTavern` のReplay/パネル位置調整は `650b0823f` でコミット済みです。実行用の `data/default-user/extensions/kokoro-avatar` コピーも同内容ですが、SillyTavern側のignore対象です。
- 親repo remoteは `https://github.com/Kitagawa65536/EasyCharacterChatWebUI.git`。`SillyTavern` と `kokoro` はどちらも `EasyCharacterChatWebUI` ブランチを指す submodule として登録済みです。
- 親repoには Apache License 2.0 の `LICENSE` と、起動手順・CORS注意点・SillyTavern設定をまとめた `README.md` を追加済みです。
- 直近確認:
  - `kokoro` で `npm run build` 成功。Vite の `util` externalized 警告は既知の非ブロッキング警告です。
  - 2026-06-21: LLM `GET /v1/models` 成功、TTS `POST /v1/audio/speech` 成功。
  - 2026-06-21: SillyTavern UIで `Kokoro Avatar` が `Avatar: Ready`、パネル `Test` からTTS 200。
  - 2026-06-21: ChatUIから送信し、AI応答「正常に動作しています。」を表示。その後KokoroへのTTS要求も200。
  - 2026-06-21: `Replay` 未記録時の表示、Chat応答後のTTS送信、`Replay` クリック後のTTS再送をPlaywrightで確認。
  - 2026-06-21: テスト用に起動していた `kokoro` dev server `:5173` と `SillyTavern` `:8000` は停止済み。LLM `:1234` とTTS `:8088` はユーザー側サーバとして残しています。
  - 2026-06-25: `kokoro` で `npm.cmd run build` 成功。Vite の `util` externalized 警告は既知の非ブロッキング警告です。短時間のVite起動で `kokoro/logs/audio-linkage.log` への追記も確認済み。
  - 2026-06-25: 深度推定フォールバック追加後、`kokoro` で `npm.cmd run build` 成功。
  - 2026-06-25: 深度Workerの `pipeline(...)` 失敗も親側に `Depth worker failed ...` として返すように未コミット修正。次回Reload後の `audio-linkage.log` で実エラー確認が必要です。
  - 2026-06-25: `GET http://127.0.0.1:8088/v1/models` で `irodori-tts-lite` を確認。`POST http://127.0.0.1:5173/irodori-tts/v1/audio/speech` に `model=irodori-tts-lite` を投げて `200 audio/wav` を確認。

## 次のステップの作業

- 人間操作として、通常ブラウザで `http://127.0.0.1:8000/` を開き、初回だけAvatar内の `Enable Voice` をクリックします。
- 停止後に再確認する場合は、先に `.\Start-KokoroSillyTavern.ps1` で `kokoro` と `SillyTavern` を起動します。
- その後、`Kokoro Avatar` パネルの `Test`、ChatUI送信、直近応答の `Replay` を確認します。
- もし音が出ない場合は、SillyTavern側の `Replay`、Avatar側の `Play Last Speech`、ブラウザのサイト音声許可、TTSサーバ `http://127.0.0.1:8088/v1/audio/speech` の順に切り分けます。
- pushする場合は、先に submodule 側を `git -C SillyTavern push -u origin EasyCharacterChatWebUI` と `git -C kokoro push -u origin EasyCharacterChatWebUI` で送ってから、親repoを `git push -u origin EasyCharacterChatWebUI` で送ります。
- 2026-06-25: 親repoのREADME類からユーザー名を含むローカル絶対パスを削除し、外部ローカル依存はignore済みの `.local-work` junction経由で参照する運用に変更済みです。

## 口差分を作るときの依頼メモ

必要なのは次の3枚です。

- `kokoro/public/mouth/closed.png`
- `kokoro/public/mouth/half.png`
- `kokoro/public/mouth/open.png`

作成時の目安は次です。

- 透明PNG
- まずは `320x180` 前後で開始
- 口だけを描いて、位置は中央基準
- 口の周囲の肌色が必要なら軽く覆う
- 3枚は同じキャンバスサイズに揃える
- 現在の実運用素材は `380x150` で、口の上下左右に余白を持たせた版です
