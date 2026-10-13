import 'package:flutter/material.dart';

import '../l10n/language_controller.dart';
import '../widgets/gradient_button.dart';

/// Rune Puzzle Tactics — 타이틀 화면 (진입점).
///
/// Rune 모드 로비(/runeLobby)로 이동하는 단일 진입 화면이다.
/// (카드 배틀 도메인 정리 후 Rune 전용으로 재작성)
class TitleView extends StatefulWidget {
  const TitleView({super.key});

  @override
  State<TitleView> createState() => _TitleViewState();
}

class _TitleViewState extends State<TitleView> {
  @override
  Widget build(BuildContext context) {
    final l10n = LanguageScope.of(context).strings;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background/opening.jpg'),
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 메인 레이아웃 (하단 버튼)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  const Spacer(),
                  // 전투 시작 버튼 (하단 고정)
                  SizedBox(
                    width: double.infinity,
                    // 요구사항 1.1: 타이틀 → 메인 허브 이동 시 pushReplacement로
                    // 타이틀 화면을 내비게이션 스택에서 제거한다. 뒤로가기로
                    // 타이틀에 돌아오지 않게 하여 '앱 종료 확인' 흐름만 남긴다.
                    child: GradientButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushReplacementNamed('/runeLobby'),
                      icon: Icons.auto_awesome,
                      label: l10n.tr('title_start'),
                      height: 58,
                      glow: true,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 50), // 하단 여백
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
