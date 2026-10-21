import 'dart:math' as math;
import 'dart:typed_data';

/// The median fundamental frequency (F0) of [samples] in Hz, or null when too
/// little of it is voiced.
///
/// YIN on 40 ms frames every 10 ms, after reducing to 8 kHz; frames quieter
/// than -40 dBFS are skipped. Searches 50–500 Hz.
double? estimatePitch(Int16List samples, int sampleRate) =>
    _estimate(samples, sampleRate).$1;

/// [estimatePitch] and the share of loud frames that were voiced.
(double?, double) estimatePitchWithVoicing(Int16List samples, int sampleRate) =>
    _estimate(samples, sampleRate);

const _rate = 8000;
const _minHz = 50.0;
const _maxHz = 500.0;
const _threshold = 0.15;
const _silence = 328; // -40 dBFS RMS

(double?, double) _estimate(Int16List samples, int sampleRate) {
  final x = _downsample(samples, sampleRate);
  const window = _rate * 40 ~/ 1000;
  const hop = _rate * 10 ~/ 1000;
  final maxLag = (_rate / _minHz).ceil();
  final minLag = (_rate / _maxHz).floor();
  final d = Float64List(maxLag + 1);
  final f0s = <double>[];
  var loud = 0;
  for (var start = 0; start + window + maxLag <= x.length; start += hop) {
    var energy = 0.0;
    for (var i = start; i < start + window; i++) {
      energy += x[i] * x[i];
    }
    if (math.sqrt(energy / window) < _silence) continue;
    loud++;
    // Difference function and its cumulative mean normalization (YIN).
    for (var lag = 1; lag <= maxLag; lag++) {
      var s = 0.0;
      for (var i = start; i < start + window; i++) {
        final v = x[i] - x[i + lag];
        s += v * v;
      }
      d[lag] = s;
    }
    var sum = 0.0;
    d[0] = 1;
    for (var lag = 1; lag <= maxLag; lag++) {
      sum += d[lag];
      d[lag] = sum == 0 ? 1 : d[lag] * lag / sum;
    }
    int? best;
    for (var lag = minLag; lag < maxLag; lag++) {
      if (d[lag] < _threshold) {
        while (lag + 1 < maxLag && d[lag + 1] < d[lag]) {
          lag++;
        }
        best = lag;
        break;
      }
    }
    if (best == null) continue;
    // Parabolic interpolation around the dip.
    final a = d[best - 1], b = d[best], c = d[best + 1];
    final den = a - 2 * b + c;
    final lag = den == 0 ? best.toDouble() : best + (a - c) / (2 * den);
    f0s.add(_rate / lag);
  }
  final voicing = loud == 0 ? 0.0 : f0s.length / loud;
  if (f0s.length < 10) return (null, voicing);
  f0s.sort();
  return (f0s[f0s.length ~/ 2], voicing);
}

/// Low-passes with a moving average over the decimation step and keeps every
/// step-th sample (linear interpolation when the rate is not a multiple).
Float64List _downsample(Int16List s, int rate) {
  if (rate <= _rate) {
    return Float64List.fromList([for (final v in s) v.toDouble()]);
  }
  final step = rate / _rate;
  final width = step.ceil();
  final n = (s.length / step).floor();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final from = (i * step).floor();
    final to = math.min(from + width, s.length);
    var sum = 0.0;
    for (var j = from; j < to; j++) {
      sum += s[j];
    }
    out[i] = sum / (to - from);
  }
  return out;
}
