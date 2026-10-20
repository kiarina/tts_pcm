# tts_pcm (not published yet)

Speech synthesis to **16-bit PCM** with the OS voices, for macOS, iOS, Android and Windows.
Nothing is played: the caller gets the audio and owns the speaker, so it knows exactly what was
played and when — to give an echo canceller its reference, or to recognize its own voice in what
the microphone hears.

```dart
if (!TtsPcm.isSupported) return;                         // false on the Web
final tts = TtsPcm.instance;
final voices = await tts.voices(language: 'ja');         // ja-JP, ...
await for (final chunk in tts.synthesize(
  'こんにちは。今日はいい天気ですね。',
  language: 'ja-JP',                                      // or voice: voices.first.id
  rate: 1.0,                                              // relative to the engine's normal speed
)) {
  chunk.samples;     // Int16List, mono
  chunk.sampleRate;  // the engine's own rate (16000, 22050, 24000, 48000, ...): resample yourself
}
// To stop, cancel the subscription (listen(...).cancel()).
```

Why not [flutter_tts](https://pub.dev/packages/flutter_tts): it plays the voice itself on Windows
and gives no PCM there, and on macOS it can only write a file to a fixed folder.

No setup is needed on any platform. The Android manifest of the plugin declares the
`TTS_SERVICE` query that apps targeting API 30+ need.

## API

- `TtsPcm.instance.voices({language})` → `List<TtsVoice>`. `language: 'ja'` matches `ja-JP`;
  `ja-JP` matches only `ja-JP`.
- `TtsPcm.instance.synthesize(text, {language, voice, rate = 1.0})` → `Stream<TtsChunk>`.
  `voice` is a `TtsVoice.id`; with only `language`, the OS picks its default voice for it;
  with neither, the OS default voice. One request per call; split long text into sentences
  yourself. Requests may run at the same time.
- `TtsChunk`: `samples` (`Int16List`, mono), `sampleRate`, `nativeFormat` (what the engine produced
  before conversion, e.g. `float32 22050 Hz 1 ch`), `duration`.
- `TtsVoice`:
  - `id`, `name`: the OS's own. **An id names the voice on that platform and that device only**;
    installed voices differ from machine to machine.
  - `language`: BCP 47 with a hyphen on every platform.
  - `quality`: `low` / `normal` / `high`, or null on Windows (no levels). Apple default → low,
    enhanced → normal, premium → high; Android below `QUALITY_NORMAL` → low, normal → normal,
    above → high. Compare voices within one device, not across platforms.
  - `gender`: `male` / `female`, or null where the OS does not say (Android, many Apple voices).
  - `requiresNetwork`: true only for Android voices synthesized on a server.
  - `native`: the OS's own values (Apple `quality`, `gender`, `novelty`, `personal`; Android
    `quality`, `latency`, `features`, `notInstalled`; Windows `description`). Not a stable API.
- `TtsPcm.isSupported`: macOS, iOS, Android, Windows. The Web has no way to hand out the audio
  of `speechSynthesis`.
- Errors end the stream with `TtsPcmException(code, message)`: `unknownVoice` for an id the
  device does not have, `unavailable` when the engine could not start, `failed` otherwise.
- `TtsPcm.instance.lateChunks`: chunks that arrived after a cancel and were dropped (Android's
  engine keeps sending a few).

## Platforms

| | macOS 12+ / iOS 15+ | Android (API 24+) | Windows 10/11 |
| --- | --- | --- | --- |
| Engine | `AVSpeechSynthesizer.write` (one synthesizer per request) | `TextToSpeech.synthesizeToFile` + `onAudioAvailable` (one engine, requests in turn) | `Windows.Media.SpeechSynthesis` (`SynthesizeTextToStreamAsync`, on a worker thread) |
| Delivery | small chunks; Kyoko delivers them all at the end | as it synthesizes | one chunk per request |
| Format (default Japanese voice) | float32 22,050 Hz (new voices such as Eddy: 16,000 Hz) | 16-bit 24,000 Hz (network voices 48,000 Hz) | 16-bit 16,000 Hz |
| Cancel | stops at once | stops; a few chunks may still arrive (dropped, counted in `lateChunks`) | the result is dropped |

Measured with the example app (release builds, a 3-second Japanese sentence after the first call,
and an 11–13-second one):

| | macOS 27, MacBook Pro M1 Max | iPadOS 27, iPad Air 4 | Android 17, Pixel 6 | Windows 11, Core i9-12900K |
| --- | --- | --- | --- | --- |
| Voices (Japanese) | 180 (9) | 193 (10) | 474 (9) | 3 (3) |
| First audio, 3 s sentence | 741 ms (Kyoko); 19–141 ms (new voices) | 709 ms; 13–148 ms | 18 ms | 33 ms (the whole sentence) |
| All audio, 11–13 s sentence | 947 ms | 944 ms | 128 ms | 57 ms |
| Recognized back (CER, short / long) | 0 / 3.6 % | 0 / 3.6 % | 0 / 5.4 % | 0 / 3.6 % |

The content check synthesizes, transcribes the audio with the OS speech recognizer
([pcm_asr](https://pub.dev/packages/pcm_asr)) and compares it with the text; the errors are
homophones on the recognition side (合掌造り → 合唱作り). How natural the voices sound was not judged.

Not covered: Apple's enhanced and premium voices (not installed on the test devices), Windows'
"natural" Narrator voices (not listed by `Windows.Media.SpeechSynthesis`), other Android engines
than Google's, SSML, and texts of hundreds of characters.

## Example

`example/` runs the whole check once and writes a JSON report: the voices, each sentence twice
with timing, every Japanese voice, the transcription round trip, cancel, an unknown voice and two
requests at once. Pass `{"exit":true}` as its configuration:

- macOS / Windows: the `TTS_CONFIG` environment variable (`tool/run.ps1` builds and runs it on Windows).
- Android: `tool/android.sh` (the `config` intent extra).
- iOS: `tmp/tts_config.json` in the app container (`xcrun devicectl device copy to`); the report is
  `tmp/tts_result.json`.

`results/` holds the reports behind the tables above; `python3 tool/summary.py` prints them.

## License

MIT.
