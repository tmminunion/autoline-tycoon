import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundService {
  bool isMuted = false;

  AudioPlayer? _tapPlayer;
  AudioPlayer? _fxPlayer;

  AudioPlayer _getTapPlayer() {
    _tapPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return _tapPlayer!;
  }

  AudioPlayer _getFxPlayer() {
    _fxPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return _fxPlayer!;
  }

  Future<void> playTapBoost() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
    if (isMuted) return;
    try {
      final player = _getTapPlayer();
      await player.stop();
      await player.play(
        AssetSource('sfx/tap.wav'),
        volume: 0.75,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Safe fallback in headless test environments
    }
  }

  Future<void> playUpgrade() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
    if (isMuted) return;
    try {
      final player = _getFxPlayer();
      await player.stop();
      await player.play(
        AssetSource('sfx/upgrade.wav'),
        volume: 0.85,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  Future<void> playTierUp() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    if (isMuted) return;
    try {
      final player = _getFxPlayer();
      await player.stop();
      await player.play(
        AssetSource('sfx/tier_up.wav'),
        volume: 0.9,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  Future<void> playTurbo() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    if (isMuted) return;
    try {
      final player = _getFxPlayer();
      await player.stop();
      await player.play(
        AssetSource('sfx/turbo.wav'),
        volume: 0.9,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  void dispose() {
    try {
      _tapPlayer?.dispose();
      _fxPlayer?.dispose();
    } catch (_) {}
  }
}
