import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeroRoster', () {
    test('초기: Fire Hero 1명 자동 지급 + 편성 (RPT-25)', () {
      final r = HeroRoster.initial();
      expect(r.partyCount(RuneElement.fire), 1);
      expect(r.ownedCount(RuneElement.fire), 1);
      expect(r.partyTotal, 1);
      expect(r.ownedTotal, 1);
      expect(r.partyIds, [HeroPool.starter.heroId]);
    });

    test('속성별 인원수는 편성 상태를 그대로 반영한다 (배율은 없다)', () {
      final r = HeroRoster();
      expect(r.partyCount(RuneElement.water), 0);

      // 서로 다른 속성 영웅을 하나씩 편성한다 (id 기반).
      const ids = ['water_a', 'light_a', 'fire_a', 'grass_a'];
      for (var i = 0; i < ids.length; i++) {
        r.grant(ids[i]);
        expect(r.assign(ids[i]), isTrue);
        expect(r.partyTotal, i + 1);
      }

      // 각 속성 인원수는 편성 상태를 반영한다.
      expect(r.partyCount(RuneElement.water), 1);
      expect(r.partyCount(RuneElement.light), 1);
      expect(r.partyCount(RuneElement.fire), 1);
      expect(r.partyCount(RuneElement.grass), 1);
      expect(r.partyTotal, HeroRoster.maxPartySize);
    });

    test('인원수는 데미지 배율이 아니다 — 같은 색 공격력 합이 밑이 된다', () {
      // 이 테스트가 보호하는 것: `partyCount` 가 배율표로 다시 쓰이지 않는다.
      // 매칭 데미지 축은 [BattleState.attackForElement] 이며, 그것은 인원수가 아니라
      // **공격력 합**을 읽는다. 두 값은 우연히 같아 보이지만 다른 숫자다.
      final r = HeroRoster();
      r.grant('water_a'); // ATK 13 (서포터)
      r.assign('water_a');
      expect(r.partyCount(RuneElement.water), 1);

      final stage = _stage();
      final state = BattleState(
        stage: stage,
        party: r,
        board: PuzzleBoard(),
        partyMaxHp: 100,
        baseAttack: 0,
        heroStats: [
          HeroCombatStats(
            heroId: 'water_a',
            element: RuneElement.water,
            hp: HeroPool.byId('water_a')!.hp,
            attack: HeroPool.byId('water_a')!.attack,
            defense: HeroPool.byId('water_a')!.defense,
          ),
        ],
      );
      expect(
        state.attackForElement(RuneElement.water),
        HeroPool.byId('water_a')!.attack,
      );
    });

    test('파티 정원 제한 (RPT-21, RPT-289)', () {
      final r = HeroRoster();
      const candidates = ['fire_a', 'water_a', 'grass_a', 'light_a', 'poison_a'];
      for (final id in candidates.take(HeroRoster.maxPartySize)) {
        r.grant(id);
        expect(r.assign(id), isTrue);
      }
      expect(r.partyTotal, HeroRoster.maxPartySize);
      // 남은 후보는 보유만 되고 편성은 정원에 막힌다.
      for (final id in candidates.skip(HeroRoster.maxPartySize)) {
        r.grant(id);
        expect(r.assign(id), isFalse, reason: '정원 초과');
      }
      expect(r.partyTotal, HeroRoster.maxPartySize);
      expect(r.ownedTotal, candidates.length);
    });

    test('동일 영웅 중복 편성 불가', () {
      final r = HeroRoster();
      r.grant('fire_a');
      expect(r.assign('fire_a'), isTrue);
      expect(r.assign('fire_a'), isFalse); // 이미 편성
      expect(r.partyTotal, 1);
    });

    test('N은 Owned가 아니라 Party 기준 (RPT-290, RPT-292)', () {
      final r = HeroRoster();
      r.grant('fire_a');
      r.grant('water_a');
      r.grant('grass_a'); // Owned 3
      r.assign('fire_a');
      r.assign('water_a'); // Party 2
      expect(r.ownedTotal, 3);
      expect(r.partyTotal, 2);
      expect(r.ownedCount(RuneElement.fire), 1);
      expect(r.partyCount(RuneElement.water), 1);
    });

    test('보유 없이는 편성 불가 / 해제(Unassign)', () {
      final r = HeroRoster();
      expect(r.assign('water_a'), isFalse); // 보유 0
      r.grant('water_a');
      expect(r.assign('water_a'), isTrue);
      r.unassign('water_a');
      expect(r.partyCount(RuneElement.water), 0);
      expect(r.ownedCount(RuneElement.water), 1);
    });

    test('fromIds: 편성은 Owned 에 포함된 영웅만', () {
      final r = HeroRoster.fromIds(
        ['fire_a', 'poison_a'],
        ownedIds: ['fire_a', 'water_a'],
      );
      expect(r.partyIds, ['fire_a']); // poison_a 는 미보유라 제외
      expect(r.ownedIds, ['fire_a', 'water_a']);
    });

    test('partyHeroes 는 id 순서를 보존하고 정의를 붙인다', () {
      final r = HeroRoster.fromIds(
        ['water_a', 'fire_a'],
        ownedIds: ['water_a', 'fire_a'],
      );
      expect(
        r.partyHeroes.map((h) => h.heroId),
        ['water_a', 'fire_a'],
      );
      // 편성 순서 보존 + 스탯은 영웅별 고유값
      expect(r.partyHeroes.first.attack, HeroPool.byId('water_a')!.attack);
    });
  });
}

/// 테스트용 스테이지 — 상성은 Fire 약점 / Water 열세로 고정한다.
StageConfig _stage() => const StageConfig(
  stageNumber: 1,
  type: StageType.normal,
  monsterHp: 100,
  monsterAttack: 10,
  weakElement: RuneElement.fire,
  resistElement: RuneElement.water,
  bossCountdown: 0,
  blackSpawnRate: 0.05,
  maxBlackOnBoard: 6,
  blackDamage: 10,
  goldReward: 0,
);
