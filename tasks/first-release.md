# 0.1.0 を pub.dev に出す

lab の plugin をこの repo に移し、声の一覧の形をそろえ（`quality`・`gender`・`requiresNetwork`・`native`）、`isSupported` と
`TtsPcmException.code`（`unknownVoice`）を足した。macOS・iOS（iPad Air 4）・Android（Pixel 6）・Windows で example を流して確かめた
（`results/*-1.json`、2026-10-20）。

- [ ] オーナーに名前・version・公開内容・対応範囲と `flutter pub publish --dry-run` の結果を見せ、承認をもらう
- [ ] `publish_to: none` を外して公開する。README の見出しの「(not published yet)」を外す
- [ ] publisher `kiarina.dev` の付与（pub.dev のサイトでオーナーが行う）
- [ ] 公開した版を Spirits Garden の試作の依存にする（今は git の依存）
- [ ] CI の最初の run が緑か確かめる
