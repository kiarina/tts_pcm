import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tts_pcm/tts_pcm.dart';

/// A voiced-like tone: [hz] with its first harmonics, gliding ±5 %.
Int16List tone(double hz, int rate, {double seconds = 2}) {
  final n = (rate * seconds).round();
  final out = Int16List(n);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final f = hz * (1 + 0.05 * math.sin(2 * math.pi * i / n));
    phase += 2 * math.pi * f / rate;
    var v = 0.0;
    for (var k = 1; k <= 5; k++) {
      v += math.sin(k * phase) / k;
    }
    out[i] = (v * 6000).round();
  }
  return out;
}

TtsVoice voice(
  String id, {
  TtsVoiceQuality? quality,
  bool network = false,
  Map<String, Object?> native = const {},
}) => TtsVoice(
  id: id,
  name: id,
  language: 'ja-JP',
  quality: quality,
  requiresNetwork: network,
  native: native,
);

void main() {
  group('estimatePitch', () {
    for (final rate in [16000, 22050, 24000, 48000]) {
      for (final hz in [95.0, 130.0, 210.0, 290.0]) {
        test('$hz Hz at $rate Hz', () {
          final f0 = estimatePitch(tone(hz, rate), rate)!;
          expect((f0 - hz).abs() / hz, lessThan(0.03), reason: '$f0');
        });
      }
    }

    test('silence and noise have none', () {
      expect(estimatePitch(Int16List(32000), 16000), isNull);
      final r = math.Random(1);
      final noise = Int16List.fromList([
        for (var i = 0; i < 32000; i++) r.nextInt(20000) - 10000,
      ]);
      expect(estimatePitch(noise, 16000), isNull);
    });
  });

  group('pickVoice', () {
    final voices = [
      voice('deep', quality: TtsVoiceQuality.low),
      voice('mid-low', quality: TtsVoiceQuality.low),
      voice('mid-high', quality: TtsVoiceQuality.low),
      voice('very-high', quality: TtsVoiceQuality.low),
      voice('net-low', network: true, quality: TtsVoiceQuality.high),
      voice('novelty', native: {'novelty': true}),
      voice('unmeasured'),
    ];
    final pitches = [
      const TtsVoicePitch(voiceId: 'deep', hz: 80),
      const TtsVoicePitch(voiceId: 'mid-low', hz: 125),
      const TtsVoicePitch(voiceId: 'mid-high', hz: 215),
      const TtsVoicePitch(voiceId: 'very-high', hz: 320),
      const TtsVoicePitch(voiceId: 'net-low', hz: 120),
      const TtsVoicePitch(voiceId: 'novelty', hz: 118),
      const TtsVoicePitch(voiceId: 'whisper', hz: null),
    ];

    test('closest to the target on each side, not the extreme', () {
      expect(pickVoice(voices, pitches, TtsPitch.low)?.id, 'mid-low');
      expect(pickVoice(voices, pitches, TtsPitch.high)?.id, 'mid-high');
    });

    test('a custom target', () {
      expect(
        pickVoice(voices, pitches, TtsPitch.low, targetHz: 85)?.id,
        'deep',
      );
      expect(
        pickVoice(voices, pitches, TtsPitch.high, targetHz: 300)?.id,
        'very-high',
      );
    });

    test('higher quality wins over closeness', () {
      final v = [...voices, voice('premium', quality: TtsVoiceQuality.high)];
      final p = [...pitches, const TtsVoicePitch(voiceId: 'premium', hz: 150)];
      expect(pickVoice(v, p, TtsPitch.low)?.id, 'premium');
      expect(pickVoice(v, p, TtsPitch.high)?.id, 'mid-high');
    });

    test('splits at the widest gap, not at a fixed line', () {
      // Google's Japanese voices on a Pixel 6.
      final v = [
        for (final id in ['jab', 'jac', 'jad', 'htm']) voice(id),
      ];
      final p = [
        const TtsVoicePitch(voiceId: 'jab', hz: 287),
        const TtsVoicePitch(voiceId: 'jac', hz: 160),
        const TtsVoicePitch(voiceId: 'jad', hz: 173),
        const TtsVoicePitch(voiceId: 'htm', hz: 301),
      ];
      expect(pickVoice(v, p, TtsPitch.low)?.id, 'jac');
      expect(pickVoice(v, p, TtsPitch.high)?.id, 'jab');
    });

    test('voices all on one side leave the other empty', () {
      final v = [voice('a'), voice('b')];
      final p = [
        const TtsVoicePitch(voiceId: 'a', hz: 230),
        const TtsVoicePitch(voiceId: 'b', hz: 290),
      ];
      expect(pickVoice(v, p, TtsPitch.low), isNull);
      expect(pickVoice(v, p, TtsPitch.high)?.id, 'a');
    });

    test('null when no voice is on that side', () {
      expect(pickVoice([voices[3]], pitches, TtsPitch.low), isNull);
      expect(pickVoice(voices, const [], TtsPitch.high), isNull);
    });
  });

  test('TtsVoicePitch round-trips through JSON', () {
    const p = TtsVoicePitch(voiceId: 'a', hz: 123.4, voicing: 0.8);
    final q = TtsVoicePitch.fromJson(p.toJson());
    expect([q.voiceId, q.hz, q.voicing, q.error], ['a', 123.4, 0.8, null]);
    const e = TtsVoicePitch(voiceId: 'b', hz: null, error: 'x');
    expect(TtsVoicePitch.fromJson(e.toJson()).error, 'x');
  });
}
