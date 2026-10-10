/// Rune Puzzle Tactics — Play(전투 재화) 부족 안내 팝업 공용 (요구사항 3.1 / 6.3)
///
/// Play 입장 비용이 부족한 상황에서 [보상형 광고 보기] / 취소를 제공한다.
/// 결과는 pop 값으로 전달된다:
///   - 'ad'   → 보상형 광고로 Play 충전 (호출부가 충전 후 재시도)
///   - null   → 취소
///
/// ValueKey('play-shortage-dialog')와 동작 pop 값('ad'/null)을 유지한다.
library;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter/material.dart';

import '../l10n/language_controller.dart';
import 'gradient_button.dart';

/// Play 부족 안내 팝업을 표시하고 사용자가 고른 동작('ad'/null)을 반환.
///
/// 허브(Lobby), 배틀 진입, 결과 화면(요구사항 6.3)에서 동일한 팝업을 공유한다.
Future<String?> showPlayShortageDialog(BuildContext context) {
  final l10n = LanguageScope.of(context).strings;
  return showDialog<String>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (ctx) => Dialog(
      key: const ValueKey('play-shortage-dialog'),
      backgroundColor: const Color(0xFF20262A),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.tr('entry_short_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.trp('entry_error_no_play', {'n': RuneMeta.stageEntryCost}),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              GradientButton(
                key: const ValueKey('shortage-watch-ad'),
                onPressed: () => Navigator.pop(ctx, 'ad'),
                icon: Icons.play_circle_outline,
                label: l10n.trp('entry_short_watch_ad', {
                  'n': RuneMeta.rewardedAdPlay,
                }),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.tr('common_cancel')),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
