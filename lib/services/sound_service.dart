import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundService {
  bool isMuted = false;

  AudioPlayer? _laserPlayer;
  AudioPlayer? _fxPlayer;
  AudioPlayer? _explPlayer;

  int _lastLaserMs = 0;
  int _lastCoinMs = 0;

  AudioPlayer _getLaserPlayer() {
    _laserPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return _laserPlayer!;
  }

  AudioPlayer _getFxPlayer() {
    _fxPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return _fxPlayer!;
  }

  AudioPlayer _getExplPlayer() {
    _explPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return _explPlayer!;
  }

  Future<void> playLaser() async {
    if (isMuted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLaserMs < 110) return;
    _lastLaserMs = now;
    try {
      final p = _getLaserPlayer();
      await p.stop();
      await p.play(
        AssetSource('sfx/laser.wav'),
        volume: 0.35,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  Future<void> playCoin() async {
    if (isMuted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCoinMs < 70) return;
    _lastCoinMs = now;
    try {
      final p = _getFxPlayer();
      await p.stop();
      await p.play(
        AssetSource('sfx/coin.wav'),
        volume: 0.55,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  Future<void> playExplosion({bool heavy = false}) async {
    try {
      if (heavy) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {}
    if (isMuted) return;
    try {
      final p = _getExplPlayer();
      await p.stop();
      await p.play(
        AssetSource('sfx/explosion.wav'),
        volume: heavy ? 0.9 : 0.6,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  Future<void> playPowerUp() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
    if (isMuted) return;
    try {
      final p = _getFxPlayer();
      await p.stop();
      await p.play(
        AssetSource('sfx/powerup.wav'),
        volume: 0.85,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  Future<void> playHit() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    if (isMuted) return;
    try {
      final p = _getFxPlayer();
      await p.stop();
      await p.play(
        AssetSource('sfx/hit.wav'),
        volume: 0.85,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  Future<void> playEmp() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    if (isMuted) return;
    try {
      final p = _getFxPlayer();
      await p.stop();
      await p.play(
        AssetSource('sfx/emp.wav'),
        volume: 0.95,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  void dispose() {
    try {
      _laserPlayer?.dispose();
      _fxPlayer?.dispose();
      _explPlayer?.dispose();
    } catch (_) {}
  }
}
