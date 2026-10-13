/// Rune Puzzle Tactics — 픽셀 스프라이트 기반 CTA 버튼.
///
/// `assets/UI`의 9-slice 버튼 스프라이트를 사용해 현재 이미지에 맞춘
/// FilledButton 대체 버튼이다. ValueKey/라벨/l10n 키는 그대로 유지한다.
///
/// - [onPressed]가 null이면 비활성 버튼 스프라이트로 렌더링된다.
/// - 유의: 단순 표시용(장식)이 아니며 항상 탭 동작이 존재해야 한다.
library;

import 'package:flutter/material.dart';

import '../services/game_audio_service.dart';
import 'pixel_sprite.dart';

/// 스프라이트 CTA 버튼 (FilledButton.icon 스타일 호환 API).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    this.icon,
    required this.label,
    this.foregroundColor = const Color(0xFF263238),
    this.height = 52,
    this.radius = 16,
    this.glow = true,
    this.fontSize = 16,
  });

  /// null이면 비활성 (글래스 회색 + 탭 불가).
  final VoidCallback? onPressed;
  final IconData? icon;
  final String label;
  final Color foregroundColor;
  final double height;
  final double radius;
  final bool glow;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius / 2),
        boxShadow: enabled && glow
            ? const [
                BoxShadow(
                  color: Color(0x80000000),
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius / 2),
        clipBehavior: Clip.hardEdge,
        child: PixelSprite(
          asset: enabled
              ? 'assets/UI/UI_Flat_Button02a_3.png'
              : 'assets/UI/UI_Flat_Button02a_1.png',
          centerSlice: const Rect.fromLTRB(8, 8, 24, 24),
          child: SizedBox.expand(
            child: InkWell(
              onTap: onPressed == null
                  ? null
                  : () {
                      GameAudioService.instance.playEffect(GameSound.uiTap);
                      onPressed!();
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 20,
                        color: enabled
                            ? foregroundColor
                            : const Color(0xFF687780),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          color: enabled
                              ? foregroundColor
                              : const Color(0xFF687780),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
