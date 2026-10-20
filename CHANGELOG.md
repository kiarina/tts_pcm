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
