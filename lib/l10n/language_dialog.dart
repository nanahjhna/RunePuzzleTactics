/// Rune Puzzle Tactics — 언어 선택 다이얼로그 (Localization §7)
///
/// 표시 순서: English → 한국어 → 日本語 → 简体中文 → 繁體中文
/// ([AppLanguage.values] 순서).
/// 언어를 선택하면 1) 현재 언어 변경 2) UI 즉시 갱신 3) SharedPreferences 저장
/// 4) 다이얼로그 닫기 가 수행된다. 앱 재시작은 필요 없다.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_language.dart';
import 'language_controller.dart';

/// 언어 선택 다이얼로그를 표시하고, 선택된 언어를 [LanguageScope] 컨트롤러에 적용한다.
Future<void> showLanguageDialog(BuildContext context) async {
  final controller = LanguageScope.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final l10n = LanguageScope.of(ctx).strings;
      return AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: Text(
          l10n.tr('lang_dialog_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in AppLanguage.values)
              ListTile(
                key: ValueKey('lang-${lang.code}'),
                dense: true,
                title: Text(
                  lang.displayName,
                  style: TextStyle(
                    color: lang == controller.language
                        ? AppColors.accent
                        : Colors.white70,
                    fontWeight: lang == controller.language
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: lang == controller.language
                    ? const Icon(Icons.check, color: AppColors.accent, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  // 다이얼로그를 닫은 뒤 즉시 적용 + 저장 (재시작 불필요).
                  controller.setLanguage(lang);
                },
              ),
          ],
        ),
      );
    },
  );
}
