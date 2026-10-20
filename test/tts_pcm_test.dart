import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tts_pcm/tts_pcm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tts_pcm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final tts = TtsPcm.instance;
  final calls = <MethodCall>[];

  /// Sends a native-to-Dart call on the channel, as the platform would.
  Future<void> fromNative(String method, Map<String, Object?> args) =>
      messenger.handlePlatformMessage(
        'tts_pcm',
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'voices':
          return [
            {
              'id': 'com.apple.voice.compact.ja-JP.Kyoko',
              'name': 'Kyoko',
              'language': 'ja-JP',
              'quality': 'low',
              'gender': 'female',
              'requiresNetwork': false,
              'native': {'quality': 'default', 'gender': 'female'},
            },
            {
              'id': 'ja-jp-x-jab-network',
              'name': 'ja-jp-x-jab-network',
              'language': 'ja_JP',
              'quality': 'high',
              'requiresNetwork': true,
              'native': {'quality': 400, 'latency': 300},
            },
            {'id': 'en', 'name': 'Microsoft Mark', 'language': 'en-US'},
            {'id': 'jv', 'name': 'Javanese', 'language': 'jv-ID'},
          ];
        case 'synthesize':
          if (args['voice'] == 'missing') {
            throw PlatformException(
              code: 'unknownVoice',
              message: 'no voice missing',
            );
          }
          return null;
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('voices are read into one shape and filtered by language', () async {
    final all = await tts.voices();
    expect(all, hasLength(4));
    final kyoko = all.first;
    expect(kyoko.quality, TtsVoiceQuality.low);
    expect(kyoko.gender, TtsVoiceGender.female);
    expect(kyoko.requiresNetwork, isFalse);
    expect(kyoko.native['quality'], 'default');
    expect(all[1].language, 'ja-JP', reason: 'underscore becomes a hyphen');
    expect(all[1].requiresNetwork, isTrue);
    expect(all[1].gender, isNull);
    expect(all[2].quality, isNull, reason: 'no levels on Windows');
    expect(all[2].native, isEmpty);

    expect((await tts.voices(language: 'ja')).map((v) => v.name), [
      'Kyoko',
      'ja-jp-x-jab-network',
    ]);
    expect(await tts.voices(language: 'ja_jp'), hasLength(2));
    expect(
      await tts.voices(language: 'j'),
      isEmpty,
      reason: 'whole subtags only',
    );
    expect(kyoko.toJson()['quality'], 'low');
  });

  test('chunks stream until done, with what was asked', () async {
    final stream = tts.synthesize('こんにちは', language: 'ja-JP', rate: 1.2);
    final got = <TtsChunk>[];
    final done = stream.forEach(got.add);
    await pumpEventQueue();
    final call = calls.singleWhere((c) => c.method == 'synthesize');
    final args = call.arguments as Map;
    expect(
      [args['text'], args['language'], args['voice'], args['rate']],
      ['こんにちは', 'ja-JP', null, 1.2],
    );
    await fromNative('chunk', {
      'id': args['id'],
      'pcm': Uint8List.fromList([1, 0, 2, 0]),
      'sampleRate': 22050,
      'format': 'float32 22050 Hz 1 ch',
    });
    await fromNative('done', {'id': args['id']});
    await done;
    expect(got.single.samples, [1, 2]);
    expect(got.single.sampleRate, 22050);
    expect(got.single.nativeFormat, 'float32 22050 Hz 1 ch');
  });

  test('an unknown voice fails with its code', () async {
    await expectLater(
      tts.synthesize('a', voice: 'missing').toList(),
      throwsA(
        isA<TtsPcmException>().having((e) => e.code, 'code', 'unknownVoice'),
      ),
    );
  });

  test('an engine error ends the stream with its code', () async {
    final result = tts.synthesize('a').toList();
    await pumpEventQueue();
    final id = (calls.last.arguments as Map)['id'];
    await fromNative('error', {'id': id, 'code': 'failed', 'message': 'boom'});
    await expectLater(
      result,
      throwsA(
        isA<TtsPcmException>().having((e) => e.message, 'message', 'boom'),
      ),
    );
  });

  test('cancelling tells the platform, and later chunks are counted, not delivered', () async {
    final sub = tts.synthesize('long').listen((_) => fail('cancelled'));
    await pumpEventQueue();
    final id = (calls.last.arguments as Map)['id'];
    await sub.cancel();
    expect(calls.last.method, 'cancel');
    final before = tts.lateChunks;
    await fromNative('chunk', {
      'id': id,
      'pcm': Uint8List(4),
      'sampleRate': 24000,
    });
    expect(tts.lateChunks, before + 1);
  });

  test('supported on the four platforms only', () {
    for (final (p, want) in [
      (TargetPlatform.macOS, true),
      (TargetPlatform.iOS, true),
      (TargetPlatform.android, true),
      (TargetPlatform.windows, true),
      (TargetPlatform.linux, false),
    ]) {
      debugDefaultTargetPlatformOverride = p;
      expect(TtsPcm.isSupported, want, reason: '$p');
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
