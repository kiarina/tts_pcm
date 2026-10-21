# AGENTS.md

このリポジトリで作業するエージェント向けのガイドラインです。

## 作業前に読むもの

- `README.md`（公開向けの説明。API・対応表・実測）
- `lib/tts_pcm.dart`（Dart の契約。ここが正典）
- `tasks/`（残っている作業。1 タスク 1 ファイル）
- `CHANGELOG.md`

実証の来歴は labs の `2026/10/20/flutter-tts-pcm`（4 つの OS の最初の実測）。この repo は、それを写して使っていた
Spirits Garden の試作の写し（lab と同じコード）をもとに作り（2026-10-20）、以後はここが所有する。lab とは同期しない。

## 設計の決まり

- 約束は「文を 1 つ渡すと、OS の声の PCM（16 bit・モノラル）が流れてくる」だけ。**鳴らさない。** 何をいつ鳴らしたかを
  呼び出し側が正確に知るため（エコー除去の参照、マイクで聞いた自分の声の印）。再生・文の区切り・周波数の変換は呼び出し側が持つ
- サンプリングレートは OS の声のまま返す（変換しない）。元の形式は `nativeFormat` に書く
- 声の一覧は全 OS で同じ形にそろえる。`id`・`name`・`language`（BCP 47、`-` 区切り）は必ず、`quality`（low・normal・high）・
  `gender` は OS が言わなければ null（読み替えて埋めない）、`requiresNetwork`、OS の元の値は `native`（安定した API にしない）。
  読み替えは各 OS の native 側で行う（Apple: default → low・enhanced → normal・premium → high、Android: `QUALITY_NORMAL` 未満 → low・
  同じ → normal・超える → high、Windows は段階が無いので null）
- 無い声の id を指定したら、黙って既定の声にせず `unknownVoice` で失敗する（どの OS も）
- 止めるのは購読の cancel。Android はエンジンが 1 つで、止めた後にも塊が少し届くので Dart で捨てて `lateChunks` に数える
- 声の高さ（`measurePitch`・`pickVoice`）は Dart だけで持つ（8 kHz に落とした YIN）。測った値の保存といつ測るかは呼び出し側。選ぶのは高さ（Hz）で、男女では選ばない（`gender` は多くの声で null）
- Web は対象外（`speechSynthesis` に音を取り出す口が無い）。`isSupported` が false を返す
- Windows は別のスレッドで合成し、結果を窓のメッセージで platform のスレッドへ戻す（チャンネルは platform のスレッドでしか使えない）。
  C++/WinRT は Windows SDK のもの（`windowsapp`）で、NuGet は要らない
- 認証値・会話文・個人環境のパスを公開物に混ぜない

## 検証

- `flutter analyze` と `flutter test`（Dart の契約と MethodChannel の写像）
- 実機は `example/` を release で 1 回流し、`results/<os>-<n>.json` に置いて `python3 tool/summary.py` で見る。
  見るのは、声の項目がそろっているか（`voiceFields`。`malformedLanguage` が空）、無い声で `unknownVoice`、文字に戻した CER、
  cancel の後に次の頼みが通るか、2 つ同時に終わるか
- 声の高さは `{"exit":true,"pitchOnly":true}` で日本語・英語の全部の声を測る（`results/<os>-pitch.json`）。推定を疑うときは `pitchWavDir` で音を書き出し、Praat（`uvx --with praat-parselmouth`）の値と比べる
- 各 OS の流し方は README の「Example」。iOS は bundle id `jp.kiarina.ttsPcmExample`、Android は `jp.kiarina.tts_pcm_example`
- CI のビルド成功だけで実機の動作を主張しない。対応表に書く OS は実機で確かめたものだけ

## 公開

0.1.0 を 2026-10-20 に公開した（tag `v0.1.0`）。新しい版を出すときは CHANGELOG を書き、公開した commit に `git tag -a v<版> -m "tts_pcm <版>"` を打って push する（手元の git は `tag.gpgsign` が有効で、`-m` の無い `git tag` は「no tag message?」で止まる）。
pub.dev への公開は取り消せない（discontinue しかできない）。公開の前に名前・version・公開内容・対応範囲をオーナーに示し、
`flutter pub publish --dry-run` の結果を見せる。**`.pubignore` があると `.gitignore` は見られない。** build の生成物も `.pubignore` に書く（pcm_asr の 0.1.0 は `build/` が入った）。
dry-run は commit 直前の作業ツリーで、`Total compressed archive size` を見る。publisher は `kiarina.dev`（pub.dev のサイトで付ける）。
