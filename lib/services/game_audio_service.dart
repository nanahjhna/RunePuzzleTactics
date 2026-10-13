import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameSound {
  uiTap,
  match,
  combo,
  victory,
  defeat,
  monsterAttack,
  monsterHit,
  monsterDeath,

  /// 영웅 영입 슬롯머신 회전음 (프레임마다 짧게).
  gachaTick,

  /// 1연 결과 공개 임팩트.
  gachaReveal,

  /// 신규 영웅 공개 (가장 강한 축제 음).
  gachaNew,

  /// 중복 공개 (신규보다 약한 반짝임).
  gachaDup,
}

abstract interface class AudioPreferencesStore {
  Future<bool?> read(String key);
  Future<void> write(String key, bool value);
}

class SharedPreferencesAudioStore implements AudioPreferencesStore {
  @override
  Future<bool?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(key);
  }

  @override
  Future<void> write(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
  }
}

abstract interface class GameAudioBackend {
  Future<void> playMusic(String assetPath);
  Future<void> pauseMusic();
  Future<void> resumeMusic();
  Future<void> stopMusic();
  Future<void> playEffect(String assetPath);
  Future<void> dispose();
}

class AudioPlayersBackend implements GameAudioBackend {
  AudioPlayersBackend()
    : _music = AudioPlayer(),
      _effects = List<AudioPlayer>.generate(4, (_) => AudioPlayer());

  final AudioPlayer _music;
  final List<AudioPlayer> _effects;
  var _nextEffect = 0;

  @override
  Future<void> playMusic(String assetPath) async {
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.4);
    await _music.play(AssetSource(assetPath));
  }

  @override
  Future<void> pauseMusic() => _music.pause();

  @override
  Future<void> resumeMusic() => _music.resume();

  @override
  Future<void> stopMusic() => _music.stop();

  @override
  Future<void> playEffect(String assetPath) async {
    final player = _effects[_nextEffect];
    _nextEffect = (_nextEffect + 1) % _effects.length;
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(0.75);
    await player.play(AssetSource(assetPath));
  }

  @override
  Future<void> dispose() async {
    await Future.wait([
      _music.dispose(),
      for (final player in _effects) player.dispose(),
    ]);
  }
}

class GameAudioService extends ChangeNotifier with WidgetsBindingObserver {
  GameAudioService({
    AudioPreferencesStore? preferences,
    GameAudioBackend? backend,
  }) : _preferences = preferences ?? SharedPreferencesAudioStore(),
       _backend = backend ?? AudioPlayersBackend();

  static final GameAudioService instance = GameAudioService();

  static const musicAsset = 'sounds/music/Moirai written by のる.mp3';
  static const _musicPreferenceKey = 'rpt_audio_music_enabled';
  static const _effectsPreferenceKey = 'rpt_audio_effects_enabled';

  static const Map<GameSound, String> effectAssets = {
    GameSound.uiTap: 'sounds/Environment/SwitchButton1_On.wav',
    GameSound.match: 'sounds/Equipment/MatchStrike1.wav',
    GameSound.combo: 'sounds/Combat/DesignedPunch1.wav',
    GameSound.victory: 'sounds/Environment/WaterSplash1.wav',
    GameSound.defeat: 'sounds/Destruction/WoodSnap1.wav',
    GameSound.monsterAttack: 'sounds/Combat/DesignedPunch2.wav',
    GameSound.monsterHit: 'sounds/Equipment/MatchStrike2.wav',
    GameSound.monsterDeath: 'sounds/Destruction/WoodSnap1.wav',
    // ── 영웅 영입 연출 (요구사항 9) ──
    // 전용 카지노/차임 사운드가 번들에 없어 역할이 가장 가까운 파일로 대체했다.
    // 나중에 전용 사운드를 추가하면 **이 맵만** 고치면 모든 연출이 함께 바뀐다.
    GameSound.gachaTick: 'sounds/Environment/SwitchButton2_On.wav',
    GameSound.gachaReveal: 'sounds/Combat/DesignedPunch4.wav',
    GameSound.gachaNew: 'sounds/Tools/Hammer3.wav',
    GameSound.gachaDup: 'sounds/Food/SmallGlassBottles1.wav',
  };

  final AudioPreferencesStore _preferences;
  final GameAudioBackend _backend;

  bool _musicEnabled = true;
  bool _effectsEnabled = true;
  bool _initialized = false;
  bool _foreground = true;
  Future<void>? _initializeFuture;

  bool get musicEnabled => _musicEnabled;
  bool get effectsEnabled => _effectsEnabled;

  Future<void> initialize() => _initializeFuture ??= _initialize();

  Future<void> _initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _musicEnabled = await _readPreference(_musicPreferenceKey) ?? _musicEnabled;
    _effectsEnabled =
        await _readPreference(_effectsPreferenceKey) ?? _effectsEnabled;
    _initialized = true;
    notifyListeners();
    if (_musicEnabled && _foreground) await _playMusic();
  }

  Future<bool?> _readPreference(String key) async {
    try {
      return await _preferences.read(key);
    } catch (error, stackTrace) {
      debugPrint('오디오 설정 로드 실패 ($key): $error\n$stackTrace');
      return null;
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    if (_musicEnabled == enabled) return;
    _musicEnabled = enabled;
    notifyListeners();
    await _writePreference(_musicPreferenceKey, enabled);
    if (!_initialized) return;
    if (enabled && _foreground) {
      await _playMusic();
    } else if (!enabled) {
      await _stopMusic();
    }
  }

  Future<void> setEffectsEnabled(bool enabled) async {
    if (_effectsEnabled == enabled) return;
    _effectsEnabled = enabled;
    notifyListeners();
    await _writePreference(_effectsPreferenceKey, enabled);
  }

  Future<void> _writePreference(String key, bool value) async {
    try {
      await _preferences.write(key, value);
    } catch (error, stackTrace) {
      debugPrint('오디오 설정 저장 실패 ($key): $error\n$stackTrace');
    }
  }

  void playEffect(GameSound sound) {
    if (!_initialized || !_effectsEnabled) return;
    final asset = effectAssets[sound]!;
    unawaited(_playEffect(asset));
  }

  Future<void> _playMusic() async {
    try {
      await _backend.playMusic(musicAsset);
    } catch (error, stackTrace) {
      debugPrint('배경 음악 재생 실패: $error\n$stackTrace');
    }
  }

  Future<void> _pauseMusic() async {
    try {
      await _backend.pauseMusic();
    } catch (error, stackTrace) {
      debugPrint('배경 음악 일시정지 실패: $error\n$stackTrace');
    }
  }

  Future<void> _resumeMusic() async {
    try {
      await _backend.resumeMusic();
    } catch (error, stackTrace) {
      debugPrint('배경 음악 재개 실패: $error\n$stackTrace');
    }
  }

  Future<void> _stopMusic() async {
    try {
      await _backend.stopMusic();
    } catch (error, stackTrace) {
      debugPrint('배경 음악 정지 실패: $error\n$stackTrace');
    }
  }

  Future<void> _playEffect(String asset) async {
    try {
      await _backend.playEffect(asset);
    } catch (error, stackTrace) {
      debugPrint('효과음 재생 실패 ($asset): $error\n$stackTrace');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_initialized || !_musicEnabled) return;
    if (_foreground) {
      unawaited(_resumeMusic());
    } else {
      unawaited(_pauseMusic());
    }
  }

  Future<void> shutdown() async {
    WidgetsBinding.instance.removeObserver(this);
    await _backend.dispose();
    _initialized = false;
  }
}
