/// 배틀 상태 조작 테스트 공용 헬퍼 (테스트 전용).
///
/// `BattleState.partyHp` 는 파티 유닛 HP 의 **파생 getter** 이므로 직접 대입할
/// 수 없다. 테스트에서 "파티 전멸" / "파티 HP 감소" 를 흉내내려면 유닛을 조작한다.
library;

import 'dart:math';

import 'package:rune_puzzle_tactics/game/rune.dart';

/// 파티 전멸 — 모든 유닛 HP 를 0 으로 만든다 ([BattleState.partyWiped] = true).
void wipeParty(BattleState state) {
  for (final unit in state.units) {
    unit.zeroOut();
  }
}

/// 살아있는 유닛 한 명에게 피해를 준다 (파티 합계 HP 감소 → HUD 피격 연출 트리거).
///
/// 쓰러뜨리지 않도록 살아있는 유닛만 고르고, 최대 1 만 깎아 HP 가 항상 양수로
/// 남게 한다.
void damageParty(BattleState state, int amount) {
  final living = state.livingUnits;
  if (living.isEmpty) return;
  final target = living.first;
  target.applyDamage(max(1, min(amount, target.hp - 1)));
}