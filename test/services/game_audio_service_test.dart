import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_puzzle_tactics/l10n/app_language.dart';
import 'package:rune_puzzle_tactics/l10n/language_controller.dart';
import 'package:rune_puzzle_tactics/screens/rune/rune_settings_tab.dart';
import 'package:rune_puzzle_tactics/services/game_audio_service.dart';

class _MemoryAudioPreferences implements AudioPreferencesStore {
  final values = <String, bool>{};

  @override
  Future<bool?> read(String key) async => values[key];

  @override
  Future<void> write(String key, bool value) async {
    values[key] = value;
  }
}

class _FakeAudioBackend implements GameAudioBackend {
  final musicAssets = <String>[];
  final effectAssets = <String>[];
  var pauseCount = 0;
  var resumeCount = 0;
  var stopCount = 0;

  @override
  Future<void> playMusic(String assetPath) async => musicAssets.add(assetPath);

  @override
  Future<void> playEffect(String assetPath) async =>
      effectAssets.add(assetPath);

  @override
  Future<void> pauseMusic() async => pauseCount++;

  @override
  Future<void> resumeMusic() async => resumeCount++;

  @override
  Future<void> stopMusic() async => stopCount++;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selected music and sound effect assets are bundled', () async {
    final assets = [
      GameAudioService.musicAsset,
      ...GameAudioService.effectAssets.values,
    ];
    for (final asset in assets) {
      expect(
        await rootBundle.load('assets/$asset'),
        isNotNull,
        reason: 'Missing audio asset: $asset',
      );
    }
  });

  test(
    'loads preferences and routes enabled audio to the matching assets',
    () async {
      final preferences = _MemoryAudioPreferences()
        ..values['rpt_audio_music_enabled'] = true
        ..values['rpt_audio_effects_enabled'] = true;
      final backend = _FakeAudioBackend();
      final audio = GameAudioService(
        preferences: preferences,
        backend: backend,
      );
      addTearDown(() async {
        await audio.shutdown();
        audio.dispose();
      });

      await audio.initialize();
      expect(backend.musicAssets, [GameAudioService.musicAsset]);

      audio.playEffect(GameSound.match);
      audio.playEffect(GameSound.combo);
      audio.playEffect(GameSound.victory);
      audio.playEffect(GameSound.defeat);
      audio.playEffect(GameSound.monsterAttack);
      audio.playEffect(GameSound.monsterHit);
      audio.playEffect(GameSound.monsterDeath);
      // 영웅 영입 연출 사운드 (요구사항 9).
      audio.playEffect(GameSound.gachaTick);
      audio.playEffect(GameSound.gachaReveal);
      audio.playEffect(GameSound.gachaNew);
      audio.playEffect(GameSound.gachaDup);
      await Future<void>.delayed(Duration.zero);
      expect(
        backend.effectAssets,
        GameAudioService.effectAssets.entries
            .where((entry) => entry.key != GameSound.uiTap)
            .map((entry) => entry.value)
            .toList(),
      );

      await audio.setMusicEnabled(false);
      await audio.setEffectsEnabled(false);
      audio.playEffect(GameSound.combo);
      await Future<void>.delayed(Duration.zero);

      expect(backend.stopCount, 1);
      // uiTap 을 제외한 효과음 수 (기존 7 + 영웅 영입 연출 4).
      expect(backend.effectAssets, hasLength(11));
      expect(preferences.values['rpt_audio_music_enabled'], isFalse);
      expect(preferences.values['rpt_audio_effects_enabled'], isFalse);
    },
  );

  testWidgets('settings switches persist music and effects choices', (
    tester,
  ) async {
    final preferences = _MemoryAudioPreferences();
    final audio = GameAudioService(
      preferences: preferences,
      backend: _FakeAudioBackend(),
    );
    addTearDown(audio.dispose);
    await tester.pumpWidget(
      LanguageScope(
        controller: LanguageController(
          persist: false,
          initialLanguage: AppLanguage.en,
        ),
        child: MaterialApp(
          home: Scaffold(
            body: RuneSettingsTab(
              onReplayTutorial: () {},
              onResetProgress: () {},
              audioService: audio,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('audio-music-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('audio-music-toggle')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('audio-effects-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('audio-effects-toggle')));
    await tester.pump();

    expect(audio.musicEnabled, isFalse);
    expect(audio.effectsEnabled, isFalse);
    expect(preferences.values['rpt_audio_music_enabled'], isFalse);
    expect(preferences.values['rpt_audio_effects_enabled'], isFalse);
  });
}
