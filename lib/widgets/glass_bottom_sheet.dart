/// Rune Puzzle Tactics — 글래스모피즘 바텀시트 셸 (디자인 규칙 3)
///
/// 다이얼로그 대신 하단에서 올라오는 시트 형태를 제공한다:
/// - 상단 중앙 드래그 핸들 바
/// - 상단 24px 라운드 + BackdropFilter(blur 12) 반투명 판
/// - 내용은 [child]로 주입 (스크롤이 필요한 경우 호출부에서 감쌈)
///
/// 사용처: [showStagePrepDialog], [showPlayShortageDialog] 등.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_frame.dart';

/// 바텀시트 셸. [key]는 다이얼로그 식별용 ValueKey('stage-prep-dialog' 등)를
/// 그대로 유지할 수 있도록 하위 위젯이 아니라 이 위젯에 부착한다.
class GlassBottomSheet extends StatelessWidget {
  const GlassBottomSheet({super.key, required this.child, this.art});

  final Widget child;

  /// 상단 헤더 밴드 아트 ([CardArt.header]). 시트 위쪽 24px 라운드 아래에
  /// 깔리며, 이미지에 굽힌 알파로 아래 경계가 없다.
  final Widget? art;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(borderRadius: appSheetTopRadius),
      child: ClipRRect(
        borderRadius: appSheetTopRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          // 규칙 1: 반투명 표면 + 글래스 테두리.
          //
          // 예전 `BoxDecoration(border: Border(top:))` 을 9-slice 캡 스프라이트로
          // 교체했다. 테두리가 위쪽 한 줄뿐이라 **부분 테두리**고, 9-slice 가
          // 그대로는 표현하지 못한다 → 상단 밴드(코너 호 + 수평선)와 하단 밴드
          // (좌우 세로선)로 나누는 전용 규격(`kUiSheetCapSlice`)을 쓴다.
          // 좌우 세로선은 이번에 **새로 생긴** 테두리다.
          child: UiFrame.sheetCap(
            background: AppColors.glassCardStrong,
            color: AppColors.glassBorder,
            insets: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            art: art,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 상단 중앙 드래그 핸들 바 (규칙 3)
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: appPillRadius,
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
