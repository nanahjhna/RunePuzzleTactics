/// Rune Puzzle Tactics — 메인 허브 진입 경로 (PHASE 5 → PHASE 7 승격)
///
/// PHASE 5의 독립 로비(RuneLobbyView)를 하단 탭 메인 허브(RuneMainScreen)로
/// 승격했다 (프롬프트 §24: Lobby/Party/Shop/Settings).
/// 기존 호출 지점(라우트/테스트) 호환을 위해 [RuneLobbyView] 별명을 유지한다.
library;

import 'rune_main_screen.dart';

/// 메인 허브 = [RuneMainScreen]. PHASE 7 내비게이션 구조.
typedef RuneLobbyView = RuneMainScreen;
