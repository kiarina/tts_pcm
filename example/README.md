# tts_pcm example

The smallest use: synthesize a sentence and collect its PCM.

```dart
import 'dart:typed_data';

import 'package:tts_pcm/tts_pcm.dart';

Future<(Int16List, int)?> say(String text) async {
  if (!TtsPcm.isSupported) return null;
  final samples = <int>[];
  var sampleRate = 0;
  await for (final chunk in TtsPcm.instance.synthesize(text, language: 'en-US')) {
    samples.addAll(chunk.samples);
    sampleRate = chunk.sampleRate; // the engine's own rate
  }
  return (Int16List.fromList(samples), sampleRate); // play it with your own player
}
```

## The app in this folder

`lib/main.dart` is the measurement app behind the tables in the package README, not a
UI sample. Started with the configuration `{"exit":true}`, it lists the voices,
synthesizes three sentences twice with timing, tries every Japanese voice, transcribes
the audio back with [pcm_asr](https://pub.dev/packages/pcm_asr) to check its content,
cancels a request, asks for a voice that does not exist and runs two requests at once,
then writes a JSON report and exits. Without a configuration it shows a Run button.

How to pass the configuration:

- macOS / Windows: the `TTS_CONFIG` environment variable.
- Android: the `config` intent extra (base64url JSON), e.g. with `adb shell am start --es config ...`.
- iOS: `tmp/tts_config.json` in the app container (`xcrun devicectl device copy to`).

The report is printed as `TTS_PART i/n` lines and written to `tts_result.json` in the
temporary directory.
