/// Rune Puzzle Tactics — 허브 [Settings] 탭 (PHASE 7, RPT-416)
///
/// 튜토리얼 다시보기 / 오디오 / 언어 선택 / **앱 정보** / 진행도 초기화를 제공한다.
/// 언어 선택 시 즉시 적용·저장 후 다이얼로그를 닫는다 (재시작 불필요).
///
/// 앱 정보(요구사항 10): 크레딧(정보 팝업) · 별점 매기기 · 다른 앱 둘러보기.
/// 뒤의 둘은 스토어 SDK 연결 전이라 **버튼만** 있고 눌리면 "출시 준비 중" 스낵바를
/// 띄운다(`// TODO` 자리).
library;

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/language_controller.dart';
import '../../l10n/language_dialog.dart';
import '../../services/game_audio_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_sprites.dart';
import '../../widgets/card_art.dart';
import '../../widgets/glass_surface.dart';

/// Settings 탭 (메인 허브 탭 3).
class RuneSettingsTab extends StatelessWidget {
  const RuneSettingsTab({
    super.key,
    required this.onReplayTutorial,
    required this.onResetProgress,
    this.audioService,
  });

  final VoidCallback onReplayTutorial;
  final VoidCallback onResetProgress;
  final GameAudioService? audioService;

  /// 크레딯에 표기되는 앱 버전.
  ///
  /// `pubspec.yaml` 의 `version: 1.0.0+2` 와 수동 동기화한다. 빌드 번호(+2)는
  /// 스토어용이라 여기서는 노출하지 않는다.
  static const String _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    final audio = audioService ?? GameAudioService.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.tr('settings_title'),
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        // 설정 그룹 카드 (글래스 서피스)
        GlassSurface(
          padding: const EdgeInsets.all(12),
          blur: 0,
          art: const CardArt.fill(kCardArtSettings),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tr('settings_section_tutorial'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('replay-tutorial'),
                onPressed: onReplayTutorial,
                icon: const Icon(Icons.school),
                label: Text(l10n.tr('settings_replay_tutorial')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              Text(
                l10n.tr('settings_audio'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AnimatedBuilder(
                animation: audio,
                builder: (context, _) => Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        key: const ValueKey('audio-music-toggle'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.tr('settings_music')),
                        value: audio.musicEnabled,
                        onChanged: audio.setMusicEnabled,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        key: const ValueKey('audio-effects-toggle'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.tr('settings_sound_effects')),
                        value: audio.effectsEnabled,
                        onChanged: audio.setEffectsEnabled,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              Text(
                l10n.tr('settings_language'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.trp('settings_language_current', {
                        'name': LanguageScope.of(context).language.displayName,
                      }),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('select-language'),
                    onPressed: () => showLanguageDialog(context),
                    icon: const Icon(Icons.language),
                    label: Text(l10n.tr('settings_language_select')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),

              // ── 앱 정보 (요구사항 10) ──
              // 크레딧 / 별점 매기기 / 다른 앱 둘러보기 3종.
              // 뒤의 둘은 아직 연동 전이라 "출시 준비 중" 스낵바만 띄운다.
              Text(
                l10n.tr('settings_section_about'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _AboutButton(
                      buttonKey: const ValueKey('settings-credits'),
                      icon: Icons.favorite,
                      label: l10n.tr('settings_credits'),
                      onPressed: () => _showCredits(context, l10n),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AboutButton(
                      buttonKey: const ValueKey('settings-rate'),
                      icon: Icons.star_rounded,
                      label: l10n.tr('settings_rate_app'),
                      onPressed: () => _soon(context, l10n),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AboutButton(
                buttonKey: const ValueKey('settings-other-apps'),
                icon: Icons.apps,
                label: l10n.tr('settings_other_apps'),
                onPressed: () => _soon(context, l10n),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              Text(
                l10n.tr('settings_section_data'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('reset-progress'),
                onPressed: () => _confirmReset(context, l10n),
                icon: const Icon(Icons.delete_forever),
                label: Text(l10n.tr('settings_reset_progress')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            l10n.tr('settings_footer'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // 규칙 2/3: 테마 DialogTheme(글래스 + 24px 라운드)를 그대로 따른다.
        title: Text(
          l10n.tr('settings_reset_dialog_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.tr('settings_reset_dialog_msg'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.tr('common_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(l10n.tr('settings_reset_confirm')),
          ),
        ],
      ),
    );
    if (ok == true) onResetProgress();
  }

  /// 크레딧 팝업 (요구사항 10).
  ///
  /// 앱 버전은 `pubspec.yaml` 의 버전과 수동 동기화한다. 패키지 정보
  /// (`package_info_plus`)를 새로 넣지 않고 상수로 두는 이유는, 이 값이
  /// 스토어 링크/약관 URL 이나 바뀌는 일은 없고 매 빌드마다 의존성이 늘기만
  /// 하기 때문이다.
  void _showCredits(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.favorite, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              l10n.tr('credits_title'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.trp('credits_version', {'version': _appVersion}),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (final line in const [
                'credits_role_dev',
                'credits_role_art',
                'credits_role_sound',
                'credits_role_thanks',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    l10n.tr(line),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('credits-close'),
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('common_close')),
          ),
        ],
      ),
    );
  }

  /// 미연동 기능 안내 (요구사항 10).
  ///
  /// 별점 매기기 / 다른 앱 둘러보기는 스토어 SDK·개발자 페이지 구성이 확정되면
  /// 여기서 갈아끼운다. 지금은 버튼만 있고 눌리면 "출시 준비 중" 알린다.
  // TODO(설정): 스토어 SDK(in_app_review) 연동 후 `_rateApp` 으로 교체.
  void _soon(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.tr('settings_coming_soon'))));
  }
}

/// 설정 탭 앱 정보 버튼 1개 (크레딧 / 별점 / 다른 앱).
class _AboutButton extends StatelessWidget {
  const _AboutButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
      ),
    );
  }
}
