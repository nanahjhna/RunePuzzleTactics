/// Rune Puzzle Tactics — 안내자 대사창 (첫 패배 동료 영입 가이드)
///
/// 별도 NPC 아트가 없으므로 이모지 아바타 + [UiFrame] 말풍선으로 가볍게 연출한다.
/// 기능 안내형 팝업들과 달리 **서사 대사**를 전달하는 것이 목적이라, 이름표와
/// 아바타를 함께 보여준다.
///
/// 반환값:
///   - true  → CTA(주 동작)를 눌렀다.
///   - false/null → 닫기/뒤로가기/배리어 탭.
/// 호출부는 반환값을 받은 뒤(다이얼로그가 닫힌 뒤) 다음 화면 이동을 수행해야
/// 한다 — 그래야 `Navigator.pop`이 다이얼로그가 아니라 실제 라우트를 향한다.
library;

import 'package:flutter/material.dart';

import '../l10n/language_controller.dart';
import '../theme/app_theme.dart';
import 'gradient_button.dart';
import 'ui_frame.dart';

/// 안내자 대사창을 띄우고 사용자가 CTA를 눌렀는지 반환한다.
Future<bool?> showGuideDialog(
  BuildContext context, {
  required String message,
  required String ctaLabel,
  String? title,
  String? cancelLabel,
  String emoji = '🧙',
}) {
  final l10n = LanguageScope.of(context).strings;
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (ctx) => Dialog(
      key: const ValueKey('guide-dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: UiFrame.round24(
          // 부모 Dialog 안이라 세로는 콘텐츠 높이로 결정된다.
          fit: StackFit.loose,
          background: AppColors.cardDark2,
          color: AppColors.accent.withValues(alpha: 0.6),
          insets: const EdgeInsets.all(1),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 아바타 + 이름표
                Row(
                  children: [
                    UiFrame.circle38(
                      color: AppColors.accent.withValues(alpha: 0.8),
                      background: AppColors.accent.withValues(alpha: 0.15),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title ?? l10n.tr('guide_name'),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                GradientButton(
                  key: const ValueKey('guide-cta'),
                  onPressed: () => Navigator.pop(ctx, true),
                  label: ctaLabel,
                  fontSize: 15,
                ),
                if (cancelLabel != null) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      key: const ValueKey('guide-cancel'),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        cancelLabel,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
