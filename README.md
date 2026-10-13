# RunePuzzleTactics

룬 퍼즐 타격 전술 RPG — 7×7 룬 보드에서 매치를 만들어 적을 타격하는 오프라인 우선 로그라이크 배틀 퍼즐 게임.

## 개요

- **7×7 룬 보드**에서 6종 룬(🔥💧🌿⚡🌙 + ⬛ Black)을 Swap 매치
- 파티에 편성한 **속성당 N명 ⇒ 데미지 × (0.6 + N×0.2)** 시너지 (N=0이면 0.6배, N=5이면 1.6배)
- 상성은 **몬스터와 같은 속성 1.5배**(약점) / 순환 우위 1.25배 / 무관 1.0배 / 순환 열위 0.8배.
  순환은 `풀 > ⚡ > ☠ > 🔥 > 💧 > 풀`
- Black 규칙(3직접/연쇄 = 파티 피해, 4 = 데미지+라인 정화, 5 = 전체 정화)과
  **Ultimate 게이지**(정상 매치당 +5, 선택 룬 제거 ×3.0), **Combo**(파도당 +0.25)
- 제한시간 없는 턴제 전투, 월별 **Weakness 사이클**
- 진행도(골드/클리어/영웅 보유/파티)는 SharedPreferences에 로컬 저장 (오프라인 우선)
- Firebase Analytics/Crashlytics는 no-op 안전 래퍼로 연결 (미초기화 시 동작 영향 없음)

## 구조

```
lib/
  game/             Pure Dart 배틀 코어 (battle_engine, puzzle_engine, damage, ...)
  screens/rune/     Flame 배틀 UI + 로비
  services/         진행도 저장(SharedPreferences) / 분석(no-op 래퍼)
  theme/            공용 다크 테마
  main.dart         앱 진입점(타이틀 → 로비 → 배틀)
```

## 개발

```bash
flutter pub get
flutter analyze
flutter test        # 배틀 코어/위젯/저장 통합 테스트 (test/rune)
```

## 목표 플랫폼

Android / iOS (Flutter 지원 플랫폼 전반)