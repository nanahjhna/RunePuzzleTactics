import 'package:flutter/material.dart';

/// 앱 전역에서 사용하는 컬러 팔레트 (하드코딩 방지)
class AppColors {
  AppColors._();

  // 기본 배경 (로그인/타이틀/등)
  static const Color bgDeep = Color(0xFF151329);
  static const Color bgDeepest = Color(0xFF121024);
  static const Color bgGradientTop = Color(0xFF2A2460);

  // ── 글래스모피즘 / 네온 신규 디자인 토큰 (요구사항 디자인 규칙 1) ──
  /// 신규 다크 배경 베이스 (규칙 1: 배경 0xFF12131C)
  static const Color bgMain = Color(0xFF12131C);

  /// 글래스 카드 표면 (규칙 1: 0x26FFFFFF + BackdropFilter blur 12)
  static const Color glassCard = Color(0x26FFFFFF);

  /// 글래스 강조 표면 (시트/하단 바 등)
  static const Color glassCardStrong = Color(0x33FFFFFF);

  /// 글래스 카드 테두리
  static const Color glassBorder = Color(0x40FFFFFF);

  /// Accent / Gold (규칙 1: 0xFFFFB300)
  static const Color accentGold = Color(0xFFFFB300);

  /// Primary CTA 그라데이션 시작/끝 (규칙 1: FF7E5F → FF2525)
  static const Color ctaGradStart = Color(0xFFFF7E5F);
  static const Color ctaGradEnd = Color(0xFFFF2525);

  /// Primary CTA Outer Neon Glow Shadow 색상
  static const Color glowNeon = Color(0x66FF2525);

  // 카드 & 패널
  static const Color cardDark = Color(0xFF201D3D); // 다이얼로그 배경 등
  static const Color cardDark2 = Color(0xFF221F42); // 리스트 카드
  static const Color cardTop = Color(0xFF1B183B); // 헤더/탭 배경

  // 액센트
  static const Color accent = Color(0xFFFFB300); // 메인 브랜드 컬러 (골드, 규칙 1)
  static const Color accentOrange = Color(0xFFFF8B00);
  static const Color iconButtonBg = Color(0x2DFFFFFF); // 톱바 아이콘 버튼 (글래스) 배경
  static const Color attendanceUnclaimed = Color(0xFF2E266D); // 출석 미수령 배경
  static const Color playCoinBlue = Color(0xFF69B8FF); // 플레이재화 포인트

  // 판정 / 난이도 / 랭크 공용 포인트 컬러
  static const Color green = Color(0xFF2ED573);
  static const Color blue = Color(0xFF1E90FF);
  static const Color orange = Color(0xFFFFA502);
  static const Color red = Color(0xFFFF4757);
  static const Color purple = Color(0xFF9B59B6);
  static const Color pink = Color(0xFFFF6B81);
  static const Color danger = Color(0xFFFF6B6B); // HP / 패배 등 경고

  // 전투 화면 전용 (레트로 우드톤)
  static const Color battlePanel = Color(0xFF2B2218);
  static const Color battleInset = Color(0xFF120E0A);
  static const Color battleBorder = Color(0xFF5C4734);
  static const Color battleBorderDim = Color(0xFF705842);
  static const Color battleBorderSoft = Color(0xFF4A3B2C);
  static const Color battleCard = Color(0xFF1F1812);
  static const Color battleButtonBg = Color(0xFF3A2C1F);
  static const Color battleEmpty = Color(0xFF1A120B);
  static const Color battleEmptyBorder = Color(0xFF3A2E1F);
  static const Color battleEmptyText = Color(0xFF5C4A2E);
  static const Color battleCooldownBg = Color(0xFF2B1A0A);
  static const Color battleDownBg = Color(0xFF3A1F1F);
  static const Color battleReadyBg = Color(0xFF123A1F);
  static const Color battleInsetBorder = Color(0xFF5C3A12);
  static const Color battleAvatarDown = Color(0xFF2A1A1A);
  static const Color battleAvatarReady = Color(0xFF1E3320);
  static const Color battleAvatarCooldown = Color(0xFF2B1E12);
  static const Color battleFieldBgTop = Color(0xFF2D3B45);
  static const Color battleFieldBgBottom = Color(0xFF0F171E);

  // 전투 하이라이트 포인트 컬러 (배틀 뷰 리터럴 정리)
  static const Color gold = Color(0xFFD4AF37); // 전투 골드 액센트
  static const Color selectYellow = Color(0xFFF1C40F); // 선택/강조 노랑
  static const Color readyGreen = Color(0xFF2ECC71); // 준비 완료 초록
  static const Color damageRed = Color(0xFFE74C3C); // 데미지 강조
  static const Color burnOrange = Color(0xFFE67E22); // 화상 주황
  static const Color warningOrange = Color(0xFFF39C12); // 쿨다운/경고 주황
  static const Color ultBlue = Color(0xFF3498DB); // 궁극기/쉴드 파랑
  static const Color battleScene = Color(0xFF050508); // 전투 화면 배경
}

/// 난이도별 컬러 매핑 (중복 로직 통합)
Color difficultyColor(String diff) {
  switch (diff.toUpperCase()) {
    case 'EASY':
      return AppColors.green;
    case 'NORMAL':
      return AppColors.blue;
    case 'HARD':
      return AppColors.orange;
    case 'EXPERT':
      return AppColors.red;
    case 'MASTER':
      return AppColors.purple;
    default:
      return AppColors.accent;
  }
}

/// 랭크별 컬러 매핑 (중복 로직 통합)
Color rankColor(String rank) {
  switch (rank.toUpperCase()) {
    case 'S':
      return AppColors.accent;
    case 'A':
      return AppColors.green;
    case 'B':
      return AppColors.blue;
    case 'C':
      return AppColors.orange;
    case 'F':
      return AppColors.red;
    default:
      return const Color(0xFF888888);
  }
}

/// 점수를 콤마 구분 문자열로 포맷 (예: 1,234,500)
String formatScore(int score) {
  final s = score.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 상점/인벤토리 공용 SegmentedButton 스타일
ButtonStyle get appSegmentedStyle => SegmentedButton.styleFrom(
  backgroundColor: AppColors.cardTop,
  selectedBackgroundColor: AppColors.accent,
  selectedForegroundColor: Colors.black,
  foregroundColor: Colors.white70,
  side: const BorderSide(color: Colors.white12),
  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
  visualDensity: VisualDensity.compact,
);

/// 공용 카드 모서리
BorderRadius get appCardRadius => BorderRadius.circular(16);

/// 공용 버튼/대형 카드 모서리 (규칙 2: 16)
BorderRadius get appButtonRadius => BorderRadius.circular(16);

/// 팝업/바텀시트/하단 바 모서리 (규칙 2: 24)
BorderRadius get appDialogRadius => BorderRadius.circular(24);

/// 재화/상태 칩 Pill 모서리 (규칙 2: 50)
BorderRadius get appPillRadius => BorderRadius.circular(50);

/// 공용 바텀시트 상단 라운드 (규칙 2: 24)
const BorderRadius appSheetTopRadius = BorderRadius.vertical(
  top: Radius.circular(24),
);

/// Primary CTA 그라데이션 (규칙 1: FF7E5F → FF2525)
LinearGradient get appCtaGradient => const LinearGradient(
  colors: [AppColors.ctaGradStart, AppColors.ctaGradEnd],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Primary CTA Outer Neon Glow (규칙 1)
List<BoxShadow> get appNeonGlow => const [
  BoxShadow(
    color: AppColors.glowNeon,
    blurRadius: 18,
    spreadRadius: 1,
    offset: Offset(0, 4),
  ),
];

/// 글래스 카드 표면용 BoxDecoration (규칙 1: 반투명 + 흰 테두리)
BoxDecoration appGlassDecoration({
  double radius = 16,
  Color color = AppColors.glassCard,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
  );
}

/// 네온 테마의 앱 전역 ThemeData
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF2525),
        brightness: Brightness.dark,
      ),
      // 규칙 1: 다크 테마 배경 0xFF12131C
      scaffoldBackgroundColor: AppColors.bgMain,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NeonPageTransitionsBuilder(),
          TargetPlatform.iOS: _NeonPageTransitionsBuilder(),
          TargetPlatform.windows: _NeonPageTransitionsBuilder(),
          TargetPlatform.macOS: _NeonPageTransitionsBuilder(),
          TargetPlatform.linux: _NeonPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: appButtonRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: appButtonRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: appButtonRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      // 글래스모피즘 플로팅 하단 바 (규칙 4): 배경은 호출부에서 투명 처리
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accentGold.withValues(alpha: 0.22),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      // 좌우/상단 마진을 가진 플로팅 스낵바
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.glassCardStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    // 공용 다이얼로그/바텀시트 다크 스타일
    return base.copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.glassCardStrong,
        shape: RoundedRectangleBorder(
          borderRadius: appDialogRadius,
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassCardStrong,
        shape: RoundedRectangleBorder(
          borderRadius: appCardRadius,
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Colors.white12),
    );
  }
}

/// 네온 감성의 Fade + Slide 전환 (상단에서 약하게 슬라이드)
class _NeonPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NeonPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
