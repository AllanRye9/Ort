import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for UI sound effects and ambient audio.
///
/// Sounds are optional asset files. When the asset is not bundled,
/// playback silently fails so that the app works without audio assets.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();

  bool _soundEnabled = true;
  bool _ambientEnabled = false;
  double _volume = 0.7;

  bool get soundEnabled => _soundEnabled;
  bool get ambientEnabled => _ambientEnabled;
  double get volume => _volume;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _ambientEnabled = prefs.getBool('ambient_enabled') ?? false;
    _volume = prefs.getDouble('sound_volume') ?? 0.7;
    await _sfxPlayer.setVolume(_volume);
    await _ambientPlayer.setVolume(_volume * 0.3);
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', value);
    if (!value) {
      await _ambientPlayer.stop();
    }
  }

  Future<void> setAmbientEnabled(bool value) async {
    _ambientEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ambient_enabled', value);
    if (value && _soundEnabled) {
      await _playAmbient();
    } else {
      await _ambientPlayer.stop();
    }
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sound_volume', _volume);
    await _sfxPlayer.setVolume(_volume);
    await _ambientPlayer.setVolume(_volume * 0.3);
  }

  Future<void> playClick() async {
    if (!_soundEnabled) return;
    await _playSfx('click');
  }

  Future<void> playSuccess() async {
    if (!_soundEnabled) return;
    await _playSfx('success');
  }

  Future<void> playNotification() async {
    if (!_soundEnabled) return;
    await _playSfx('notification');
  }

  Future<void> playLevelUp() async {
    if (!_soundEnabled) return;
    await _playSfx('level_up');
  }

  Future<void> playMessageSent() async {
    if (!_soundEnabled) return;
    await _playSfx('message_sent');
  }

  Future<void> _playSfx(String name) async {
    try {
      await _sfxPlayer.play(AssetSource('sounds/$name.mp3'));
    } catch (_) {
      // Asset not bundled – ignore
    }
  }

  Future<void> _playAmbient() async {
    try {
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _ambientPlayer.play(AssetSource('sounds/ambient.mp3'));
    } catch (_) {
      // Asset not bundled – ignore
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _ambientPlayer.dispose();
  }
}
