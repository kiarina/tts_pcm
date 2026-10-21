# 声の高さを測って、低い声・高い声を選べるようにする（0.2.0）

完了条件: `measurePitch`・`pickVoice` を入れ、4 つの OS の実機で日本語・英語の声の高さと選ばれる声を確かめ、オーナーの承認で 0.2.0 を pub.dev に出す。

## 背景

Spirits Garden の試作の `speak` が OS の声で話すとき、brain が声の高さ（低い・高い）を選べるようにしたい（オーナー、2026-10-22）。
声の一覧と id は OS・端末ごとに違い、`gender` は Android と多くの Apple の声で null。表を手で持つと古くなるので、
その端末の声で短い文を合成し、高さ（F0 の中央値）を測って選ぶ。男女ではなく高さ（Hz）で扱う。

## 決めたこと（2026-10-22、オーナーと）

- 測る・選ぶは tts_pcm が持つ。測った結果の保存と、いつ測るか（warmup）はアプリが持つ（tts_pcm は JSON にできる形で返すだけ）
- 保存した id が一覧から消えていたら測り直す。どの声も当てはまらなければ OS の既定の声（呼び出し側が「既定へ落ちた」と分かるように null を返す）
- 公開の前に名前・版・中身をオーナーに見せる。それまで試作は git の commit で使う

## 決めた細則（エージェント）

- 推定は Dart だけ（8 kHz に落として YIN）。依存を増やさない。native は変えない。YIN の決まったしきい値（0.15）は句の終わりの低く弱いフレームを落として
  合成の声を Praat より 5〜20% 高く読んだので、「最も深い谷が 0.45 未満なら有声、その谷 +0.05 以内の最初の谷を取る」にした（Mac・Android の 24 声で Praat と 6% 以内、平均 1.2%）。
  最も深い谷だけだと、きれいな周期の音で 2 倍の周期を取る
- 選び方: 低い・高いの境目は、その言語の声を高さで並べて、隣り合う 2 つの比が最も大きい隙間（下の声が 200 Hz 未満・上の声が 140 Hz 超のもの）。無ければ 165 Hz。
  決まった 165 Hz だと、Google の日本語の低い声（156・164 Hz）が境目をまたいで「高い声」に入った。
  その側で品質の段階が最も高いものの中から目安（低 120 Hz・高 220 Hz）に最も近い声。極端な声を選ばないため端ではなく目安に近い声にする。目安の Hz は呼び出し側が変えられる
- Apple の novelty の声、Android の未インストール・ネットワークの声は候補から外す

## 申し送り

- Android の `adb pull` は app 専用の外部ストレージ（`Android/data/<pkg>`）に書けない（Permission denied）。音を取り出すなら debug の APK で `run-as <pkg> tar cf - code_cache/tts_wavs`（Directory.systemTemp は `code_cache`）
- Windows の `run.ps1 -Config` は同じ PowerShell から呼ぶ（別の powershell.exe を通すと JSON の " が消える）
- G-GEAR には英語の声が入っていない

## 進み具合

- [x] 実装と単体テスト（2026-10-22）
- [x] example で声ごとの高さを測り、macOS・iOS（iPad Air 4）・Android（Pixel 6）・Windows（G-GEAR）の結果を `results/*-pitch.json` と README に（2026-10-22）
- [x] 試作の `speak` に `pitch` を足す（Spirits Garden 側、約束の版 36。試作は git の commit で使う）
- [ ] 選ばれる声の聞こえ方をオーナーが聞く（Apple は全部 `low` の段階なので、日本語の高い声が Kyoko でなく Flo（Eloquence）になる）。音を出すので MacBook Pro ではしない
- [x] CHANGELOG・dry-run をオーナーに見せて 0.2.0 を公開（2026-10-22、オーナーの承認。tag `v0.2.0` は `35f5cf8`）
