## 0.2.0

- `TtsPcm.instance.measurePitch(voice)` speaks a sample sentence with a voice (nothing is played) and
  measures how high it sounds: `TtsVoicePitch` (median F0 in Hz, the share of voiced frames). Plain
  data with `toJson` / `fromJson`, for the caller to keep. `measurePitches(voices, known:)` measures
  only voices not measured yet.
- `pickVoice(voices, pitches, TtsPitch.low | TtsPitch.high, {targetHz})` picks a lower or a higher
  voice: on its side of 165 Hz, of the highest quality there, the closest to 120 / 220 Hz (or
  `targetHz`). Skips Apple's novelty voices and Android voices that need the network or are not
  installed; null when none is left.
- `estimatePitch(samples, sampleRate)`: the estimator itself (YIN on 8 kHz, pure Dart).

## 0.1.0

First release.

- `TtsPcm.instance.synthesize(text, {language, voice, rate})` streams the OS voice as 16-bit mono PCM
  (`TtsChunk`: samples, the engine's own sample rate, its native format). Nothing is played.
  Cancelling the subscription stops the request.
- `voices({language})` lists the OS voices in one shape: `id`, `name`, `language` (BCP 47 with a hyphen),
  `quality` (`low` / `normal` / `high`, null on Windows), `gender` (null where the OS does not say),
  `requiresNetwork`, and the OS's own values in `native`.
- `TtsPcm.isSupported`: macOS, iOS, Android and Windows.
- `TtsPcmException.code`: `unknownVoice` for a voice id the device does not have, else what the platform reported.
