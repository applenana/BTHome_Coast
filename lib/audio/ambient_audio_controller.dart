import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract class AmbientAudioController extends ChangeNotifier {
  bool get enabled;
  bool get isPlaying;
  String? get error;

  Future<void> setScanning(bool scanning);
  Future<void> toggleEnabled();
}

class OceanAmbientAudioController extends AmbientAudioController {
  OceanAmbientAudioController({AudioPlayer? player})
    : _player = player ?? AudioPlayer(playerId: 'bthome-coast-ambience');

  static final _source = AssetSource('audio/gentle_shore.wav');
  static const _volume = 0.055;

  final AudioPlayer _player;
  bool _enabled = true;
  bool _isPlaying = false;
  bool _scanning = false;
  bool _disposed = false;
  String? _error;
  Future<void> _pending = Future<void>.value();

  @override
  bool get enabled => _enabled;

  @override
  bool get isPlaying => _isPlaying;

  @override
  String? get error => _error;

  @override
  Future<void> setScanning(bool scanning) {
    if (_scanning == scanning) return _pending;
    _scanning = scanning;
    return _queueApply();
  }

  @override
  Future<void> toggleEnabled() {
    _enabled = !_enabled;
    notifyListeners();
    return _queueApply();
  }

  Future<void> _queueApply() {
    _pending = _pending.then((_) => _apply()).catchError((Object error) {
      _isPlaying = false;
      _error = '海浪环境声暂时不可用';
      if (!_disposed) notifyListeners();
    });
    return _pending;
  }

  Future<void> _apply() async {
    if (_disposed) return;
    final shouldPlay = _enabled && _scanning;
    if (shouldPlay == _isPlaying) return;

    if (shouldPlay) {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(_source, volume: _volume);
    } else {
      await _player.stop();
    }
    _isPlaying = shouldPlay;
    _error = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_player.dispose());
    super.dispose();
  }
}

class SilentAmbientAudioController extends AmbientAudioController {
  bool _enabled = false;
  bool _scanning = false;

  @override
  bool get enabled => _enabled;

  @override
  String? get error => null;

  @override
  bool get isPlaying => _enabled && _scanning;

  @override
  Future<void> setScanning(bool scanning) async {
    if (_scanning == scanning) return;
    _scanning = scanning;
    notifyListeners();
  }

  @override
  Future<void> toggleEnabled() async {
    _enabled = !_enabled;
    notifyListeners();
  }
}
