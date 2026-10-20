/// Speech synthesis to PCM with the OS voices.
///
/// Nothing is played: the caller gets 16-bit mono PCM and owns the speaker,
/// so it knows exactly what was played and when (for an echo canceller's
/// reference, or to mark its own speech in what the microphone hears).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How good the OS says a voice is, put on one scale across platforms.
///
/// Apple: default → [low], enhanced → [normal], premium → [high].
/// Android: below `QUALITY_NORMAL` → [low], `QUALITY_NORMAL` → [normal],
/// above → [high]. Windows has no levels ([TtsVoice.quality] is null).
enum TtsVoiceQuality { low, normal, high }

enum TtsVoiceGender { male, female }

/// One voice the OS offers.
///
/// [id] is the OS's own identifier: it names the voice on this platform and
/// this device only (installed voices differ from machine to machine).
final class TtsVoice {
  final String id;
  final String name;

  /// BCP 47 with a hyphen on every platform, e.g. `ja-JP`.
  final String language;

  /// Null where the OS has no quality levels (Windows).
  final TtsVoiceQuality? quality;

  /// Null where the OS does not say (Android, some Apple voices).
  final TtsVoiceGender? gender;

  /// True only for Android voices synthesized on a server.
  final bool requiresNetwork;

  /// What the OS reported, unconverted (Apple `quality` / `gender` /
  /// `novelty` / `personal`, Android `quality` / `latency` / `features` /
  /// `notInstalled`, Windows `description`). Not part of the stable API.
  final Map<String, Object?> native;

  const TtsVoice({
    required this.id,
    required this.name,
    required this.language,
    this.quality,
    this.gender,
    this.requiresNetwork = false,
    this.native = const {},
  });

  factory TtsVoice.fromMap(Map<Object?, Object?> m) => TtsVoice(
    id: m['id']! as String,
    name: m['name']! as String,
    language: (m['language']! as String).replaceAll('_', '-'),
    quality: _byName(TtsVoiceQuality.values, m['quality']),
    gender: _byName(TtsVoiceGender.values, m['gender']),
    requiresNetwork: m['requiresNetwork'] == true,
    native: {
      for (final e in ((m['native'] as Map?) ?? const {}).entries)
        '${e.key}': e.value,
    },
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'language': language,
    'quality': quality?.name,
    'gender': gender?.name,
    'requiresNetwork': requiresNetwork,
    'native': native,
  };

  @override
  String toString() => 'TtsVoice($name, $language, ${quality?.name})';
}

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// A piece of synthesized audio: 16-bit little-endian mono PCM.
final class TtsChunk {
  final Int16List samples;
  final int sampleRate;

  /// What the engine produced before conversion to 16-bit mono, for
  /// diagnostics (e.g. `float32 22050 Hz 1 ch`).
  final String? nativeFormat;

  const TtsChunk(this.samples, this.sampleRate, [this.nativeFormat]);

  Duration get duration =>
      Duration(microseconds: samples.length * 1000000 ~/ sampleRate);
}

/// A request that failed. [code] is `unknownVoice` when [TtsPcm.synthesize]
/// names a voice this device does not have, otherwise what the platform
/// reported (`unavailable` when the engine could not start, `failed`, ...).
final class TtsPcmException implements Exception {
  final String code;
  final String message;
  const TtsPcmException(this.message, {this.code = 'failed'});
  @override
  String toString() => 'TtsPcmException($code): $message';
}

class TtsPcm {
  TtsPcm._() {
    _channel.setMethodCallHandler(_onCall);
  }

  static final TtsPcm instance = TtsPcm._();

  /// macOS, iOS, Android and Windows. False on the Web (a browser's
  /// `speechSynthesis` has no way to hand out the audio) and elsewhere, where
  /// every call fails.
  static bool get isSupported =>
      !kIsWeb &&
      const {
        TargetPlatform.macOS,
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);
  static const _channel = MethodChannel('tts_pcm');

  final Map<String, StreamController<TtsChunk>> _running = {};

  /// Chunks that arrived for a request no longer listened to (after a
  /// cancel). The engine should stop producing them; this counts how often
  /// it did not.
  int get lateChunks => _lateChunks;
  int _lateChunks = 0;
  int _next = 0;

  /// Voices the OS offers, optionally only those whose language starts with
  /// [language] (`ja` matches `ja-JP`, `ja-JP` only `ja-JP`).
  Future<List<TtsVoice>> voices({String? language}) async {
    final list = await _channel.invokeListMethod<Object?>('voices');
    final all = [
      for (final v in list ?? const <Object?>[])
        TtsVoice.fromMap(v! as Map<Object?, Object?>),
    ];
    if (language == null) return all;
    final l = language.toLowerCase().replaceAll('_', '-');
    return [
      for (final v in all)
        if (v.language.toLowerCase() == l ||
            v.language.toLowerCase().startsWith('$l-'))
          v,
    ];
  }

  /// Synthesizes [text] and streams its PCM. Pass [voice] (a [TtsVoice.id])
  /// or [language] (the OS default voice for it). [rate] is relative to the
  /// engine's normal speed (1.0). Cancel by cancelling the subscription.
  Stream<TtsChunk> synthesize(
    String text, {
    String? language,
    String? voice,
    double rate = 1.0,
  }) {
    final id = 'tts${_next++}';
    late final StreamController<TtsChunk> controller;
    controller = StreamController<TtsChunk>(
      onListen: () {
        _running[id] = controller;
        _channel
            .invokeMethod<void>('synthesize', {
              'id': id,
              'text': text,
              'language': language,
              'voice': voice,
              'rate': rate,
            })
            .catchError((Object e) {
              _finish(
                id,
                error: e is PlatformException
                    ? TtsPcmException(e.message ?? '', code: e.code)
                    : TtsPcmException('$e'),
              );
            });
      },
      onCancel: () async {
        if (_running.remove(id) != null) {
          await _channel.invokeMethod<void>('cancel', {'id': id});
        }
      },
    );
    return controller.stream;
  }

  void _finish(String id, {Object? error}) {
    final c = _running.remove(id);
    if (c == null) return;
    if (error != null) c.addError(error);
    c.close();
  }

  Future<void> _onCall(MethodCall call) async {
    final args = (call.arguments as Map<Object?, Object?>?) ?? const {};
    final id = args['id'] as String?;
    if (id == null) return;
    switch (call.method) {
      case 'chunk':
        if (!_running.containsKey(id)) {
          _lateChunks++;
          return;
        }
        final bytes = args['pcm']! as Uint8List;
        final copy = Uint8List.fromList(bytes);
        _running[id]?.add(
          TtsChunk(
            copy.buffer.asInt16List(0, copy.length ~/ 2),
            args['sampleRate']! as int,
            args['format'] as String?,
          ),
        );
      case 'done':
        _finish(id);
      case 'error':
        _finish(
          id,
          error: TtsPcmException(
            args['message'] as String? ?? '',
            code: args['code'] as String? ?? 'failed',
          ),
        );
    }
  }
}
