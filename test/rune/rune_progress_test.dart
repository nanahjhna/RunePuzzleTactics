/// Rune 진행도 모델 테스트 (PHASE 5, RPT-316 / 3-재화·HeroPool 개편)
library;

import 'dart:convert';
import 'dart:math';

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuneProgress 기본', () {
    test('초기 구성: Fire 보유 1 + 파티 1, 클리어 0 (RPT-25)', () {
      final p = RuneMeta.initial();
      expect(p.highestCleared, 0);
      expect(p.gameCurrency, 0);
      expect(p.playCurrency, RuneMeta.stageEntryCost * 5); // 시작 플레이 5
      expect(p.heroCurrency, 0);
      expect(p.nextStage, 1);
      expect(p.ownedCount(RuneElement.fire), 1);
      expect(p.partyCount(RuneElement.fire), 1);
      expect(p.ownedTotal, 1);
      expect(p.partyTotal, 1);
    });

    test('toRoster/fromRoster 라운드트립', () {
      // 물 1명 보유 + 파티 편성, 독 1명 보유
      var p = RuneMeta.initial().copyWith(
        gameCurrency: 300,
        heroCurrency: 3000,
        highestCleared: 3,
      );
      p = p.copyWith(heroOwned: {...p.heroOwned, 'water_a'});
      p = p.tryAssignHero('water_a').progress;
      p = p.copyWith(heroOwned: {...p.heroOwned, 'poison_a'});

      final roster = p.toRoster();
      expect(roster.ownedCount(RuneElement.water), 1);
      expect(roster.partyCount(RuneElement.water), 1);
      expect(roster.ownedCount(RuneElement.poison), 1);

      final back = RuneProgress.fromRoster(
        roster,
        highestCleared: p.highestCleared,
        gameCurrency: p.gameCurrency,
        playCurrency: p.playCurrency,
        heroCurrency: p.heroCurrency,
        wins: p.wins,
        losses: p.losses,
        ledger: p.ledger,
      );
      expect(back.toJson(), p.toJson());
    });

    test('JSON 라운드트립 (v3)', () {
      var p = RuneMeta.initial().copyWith(gameCurrency: 200, heroCurrency: 500);
      p = p.copyWith(heroOwned: {...p.heroOwned, 'grass_a'});
      p = p.recordClear(3, 120);
      p = p.recordDefeat();

      final decoded = RuneProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(p.toJson())) as Map),
      );
      expect(decoded.highestCleared, 3);
      expect(decoded.gameCurrency, 320);
      expect(decoded.wins, 1);
      expect(decoded.losses, 1);
      expect(decoded.ownedCount(RuneElement.grass), 1);
      expect(decoded.partyCount(RuneElement.grass), 0); // 영입 ≠ 자동 편성
      expect(decoded.toJson(), p.toJson());
    });

    test('손상/버전 불일치 JSON → 초기 구성 폴백', () {
      expect(RuneProgress.fromJson({'v': 99}).gameCurrency, 0);
      expect(RuneProgress.fromJson({'v': 99}).playCurrency, 5);
      expect(RuneProgress.fromJson({'v': 1}).partyTotal, 0);
    });
  });

  group('RuneProgress 기록', () {
    test('recordClear: 최고 스테이지 max 갱신 + Game Currency/승리 (RPT-305)', () {
      final p = RuneMeta.initial().recordClear(2, 108);
      expect(p.highestCleared, 2);
      expect(p.gameCurrency, 108);
      expect(p.wins, 1);
      expect(p.nextStage, 3);

      // 낮은 스테이지 재클리어는 최고 기록이 내려가지 않음
      final lower = p.recordClear(1, 100);
      expect(lower.highestCleared, 2);
      expect(lower.gameCurrency, 208);
      expect(lower.wins, 2);
    });

    test('recordDefeat: 패배 1 증가, 재화 변화 없음', () {
      final p = RuneMeta.initial().recordDefeat();
      expect(p.losses, 1);
      expect(p.gameCurrency, 0);
    });
  });

  group('RuneProgress 랜덤 영입 (Gacha, RPT-306 개편)', () {
    test('재화 부족 시 실패 및 상태 불변', () {
      final p = RuneMeta.initial(); // heroCurrency 0
      final r = p.tryPullHeroes(count: 1);
      expect(r.ok, isFalse);
      expect(r.reason, 'insufficient');
      expect(r.results, isEmpty);
      expect(r.progress.toJson(), p.toJson());
    });

    test('장수 범위 밖(0 / 11) 실패', () {
      final p = RuneMeta.initial().copyWith(heroCurrency: 999);
      expect(p.tryPullHeroes(count: 0).reason, 'invalid_count');
      expect(p.tryPullHeroes(count: 11).reason, 'invalid_count');
    });

    test('해금 게이트: 풀은 항상 하위 등급부터의 접두 구간 (★ 1단계뿐)', () {
      for (final stage in [1, 2, 3, 5, 8]) {
        expect(HeroGacha.availableRarities(stage), [HeroRarity.r]);
      }

      // 1스테이지 풀 = order-1 영웅 5명뿐 (스타터 포함)
      final pool = HeroGacha.poolFor(1);
      expect(pool.length, 5);
      expect(pool.every((h) => h.rarity == HeroRarity.r), isTrue);
    });

    test('성공: Hero Currency 차감 + 결과 1건, 자동 편성 없음 (프롬프트 §1)', () {
      final p = RuneMeta.initial().copyWith(heroCurrency: 10);
      final r = p.tryPullHeroes(count: 1, rng: Random(7));
      expect(r.ok, isTrue);
      expect(r.results.length, 1);
      expect(r.progress.heroCurrency, 0);
      // 파티는 스타터 1명 그대로 (신규 영웅 자동 편성 없음)
      expect(r.progress.partyTotal, 1);
    });

    test('신규 획득: 미보유 영웅은 owned 추가 + 초기 등급 유지', () {
      final base = RuneMeta.initial().copyWith(heroCurrency: 100);
      // 물 영웅만 보유한 상태에서 1연
      final p = base.copyWith(heroOwned: {...base.heroOwned, 'water_a'});
      final before = p.ownedTotal;
      final r = p.tryPullHeroes(count: 1, rng: Random(3));
      expect(r.ok, isTrue);

      final res = r.results.first;
      // 1연 = 1스테이지 풀이므로 초기 등급(R) 고정
      expect(res.gradeBefore, HeroRarity.r);
      expect(res.gradeAfter, HeroRarity.r);
      expect(
        r.progress.ownedTotal,
        before + (res.outcome == GachaOutcome.newHero ? 1 : 0),
      );
      // 자동 파티 편성 없음
      expect(r.progress.partyTotal, 1);
    });

    test('중복 영입: 뽑힌 영웅의 기존 카드가 +1 레벨 (등급 불변)', () {
      // 1스테이지 풀 5명을 전부 보유 → 다음 추첨은 반드시 중복
      final p = RuneMeta.initial().copyWith(
        heroCurrency: 100,
        heroOwned: {'fire_a', 'water_a', 'grass_a', 'light_a', 'poison_a'},
      );

      final r = p.tryPullHeroes(count: 1, rng: Random(0));
      expect(r.ok, isTrue);
      final res = r.results.single;
      // 이제 중복은 그 영웅의 카드 레벨업으로 소진된다.
      expect(res.outcome, GachaOutcome.levelUp);
      expect(res.gradeBefore, HeroRarity.r);
      expect(res.gradeAfter, HeroRarity.r);
      // 뽑힌 그 영웅이 Lv.1 → Lv.2 로 오른다.
      expect(res.levelBefore, HeroLevel.minLevel);
      expect(res.levelAfter, HeroLevel.minLevel + 1);
      expect(r.progress.heroLevel(res.hero.heroId), HeroLevel.minLevel + 1);
      expect(p.heroOwned.contains(res.hero.heroId), isTrue);
      // 등급은 그대로 (레벨은 등급과 별개 축).
      expect(r.progress.heroGrade(res.hero.heroId), HeroRarity.r);
      // 원본 스냅샷은 불변.
      expect(p.heroLevel(res.hero.heroId), HeroLevel.minLevel);
    });

    test('만렙 영웅 중복은 maxed (레벨 변화 없음)', () {
      const ids = ['fire_a', 'water_a', 'grass_a', 'light_a', 'poison_a'];
      final p = RuneMeta.initial().copyWith(
        heroCurrency: 100,
        heroOwned: {...ids},
        // 어느 영웅이 뽑혀도 만렙이 되도록 전부 최대 레벨로 둔다.
        heroLevels: {for (final id in ids) id: HeroLevel.maxLevel},
      );

      final r = p.tryPullHeroes(count: 1, rng: Random(0));
      expect(r.ok, isTrue);
      final res = r.results.single;
      expect(res.outcome, GachaOutcome.maxed);
      expect(res.levelBefore, HeroLevel.maxLevel);
      expect(res.levelAfter, HeroLevel.maxLevel);
      expect(r.progress.heroLevel(res.hero.heroId), HeroLevel.maxLevel);
    });

    test('10연 중복은 승급 대신 레벨업 (등급 불변)', () {
      // 풀을 넓혀(stage 8) 중복 확률을 만든다.
      var p = RuneMeta.initial().copyWith(heroCurrency: 500);
      p = p.copyWith(highestCleared: 7);

      final r = p.tryPullHeroes(count: 10, rng: Random(11));
      expect(r.ok, isTrue);
      expect(r.results.length, 10);
      // 등급 승급은 발생하지 않는다.
      expect(
        r.results.every((e) => e.outcome != GachaOutcome.promoted),
        isTrue,
      );
      // 중복 횟수만큼 레벨업이 일어난다(전원 Lv.1 이라 maxed 는 없음).
      final ids = r.results.map((e) => e.hero.heroId).toList();
      final dupCount = ids.length - ids.toSet().length;
      final levelUpCount = r.results
          .where((e) => e.outcome == GachaOutcome.levelUp)
          .length;
      expect(levelUpCount, dupCount);
      // 등급은 그대로 R.
      expect(r.progress.heroGrade('fire_a'), HeroRarity.r);
    });

    test('10연은 1연 10회분보다 저렴 (⭐90 / ⭐10)', () {
      final p = RuneMeta.initial().copyWith(heroCurrency: 100);
      final r = p.tryPullHeroes(count: 10, rng: Random(5));
      expect(r.ok, isTrue);
      expect(r.results.length, 10);
      expect(r.progress.heroCurrency, 10); // 100 - 90
    });

    test('등급은 저장/복원된다 (JSON heroGrades)', () {
      var p = RuneMeta.initial().copyWith(heroCurrency: 500);
      p = p.copyWith(
        heroOwned: {...p.heroOwned, 'water_a', 'grass_a'},
        heroGrades: {'grass_a': HeroRarity.r.index},
      );
      final decoded = RuneProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(p.toJson())) as Map),
      );
      expect(decoded.heroGrade('grass_a'), HeroRarity.r);
      // 미기록 영웅은 초기 등급
      expect(decoded.heroGrade('water_a'), HeroRarity.r);
      expect(decoded.toJson(), p.toJson());
    });

    test('손상된 heroGrades 는 무시 (v3 구버전 데이터 호환)', () {
      final p = RuneMeta.initial().copyWith(heroCurrency: 100);
      final json = Map<String, dynamic>.from(p.toJson());
      json['heroGrades'] = {'water_a': 99, 'nope': 1, 'fire_a': 'x'};
      final decoded = RuneProgress.fromJson(json);
      expect(decoded.heroGrade('water_a'), HeroRarity.r);
      expect(decoded.toJson()['heroGrades'], isEmpty);
    });

    test('파티 정원 초과 시 편성은 안 됨', () {
      // 초기 fire_a 편성 + 나머지 3명 수동 편성 → 정원 4
      var p = RuneMeta.initial().copyWith(heroCurrency: 20000);
      for (final id in ['water_a', 'grass_a', 'light_a']) {
        p = p.copyWith(heroOwned: {...p.heroOwned, id});
        p = p.tryAssignHero(id).progress;
      }
      expect(p.partyTotal, HeroRoster.maxPartySize);

      // 5번째 영웅 보유 → Owned+1, 파티는 정원 유지
      final seeded = p.copyWith(heroOwned: {...p.heroOwned, 'poison_a'});
      expect(seeded.ownedTotal, 5);
      expect(seeded.partyTotal, HeroRoster.maxPartySize);

      // 파티 꽉 참 → 편성 실패
      expect(seeded.tryAssignHero('poison_a').ok, isFalse);
    });
  });

  group('InMemoryRuneProgressStore', () {
    test('load/save 왕복', () async {
      final store = InMemoryRuneProgressStore();
      expect((await store.load()).partyTotal, 1); // 초기 구성

      final p = RuneMeta.initial().recordClear(4, 300);
      await store.save(p);
      expect((await store.load()).gameCurrency, 300);
    });
  });

  group('RuneProgress v3 (튜토리얼)', () {
    test('JSON 라운드트립: 튜토리얼 보존', () {
      var p = RuneMeta.initial().copyWith(gameCurrency: 3000);
      p = p.recordTutorialDone();

      final decoded = RuneProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(p.toJson())) as Map),
      );
      expect(decoded.tutorialCompleted, isTrue);
      expect(decoded.toJson(), p.toJson());
    });

    test('v1 마이그레이션: gold → gameCurrency, owned/party → heroId', () {
      final decoded = RuneProgress.fromJson(const {
        'v': 1,
        'highestCleared': 1,
        'gold': 50,
        'owned': {'fire': 2, 'water': 1},
        'party': {'fire': 1},
      });
      expect(decoded.highestCleared, 1);
      expect(decoded.gameCurrency, 50);
      expect(decoded.playCurrency, 0);
      // fire 2 → 불 영웅이 1명뿐이라 fire_a 하나 / water 1 = water_a
      expect(decoded.heroOwned, {'fire_a', 'water_a'});
      expect(decoded.heroParty, ['fire_a']);
      expect(decoded.tutorialCompleted, isFalse);
    });

    test('파티 편성/해제 (heroId 단위, RPT-289 개편)', () {
      var p = RuneMeta.initial().copyWith(heroCurrency: 1000); // Fire 1, gold 0

      // 보유 없음 → 편성 불가
      final fail = p.tryAssignHero('water_a');
      expect(fail.ok, isFalse);
      expect(fail.progress.toJson(), p.toJson());

      // 영입 → 수동 편성 → 해제 (자동 편성 없음)
      p = p.copyWith(heroOwned: {...p.heroOwned, 'water_a'});
      expect(p.partyCount(RuneElement.water), 0);

      final assign = p.tryAssignHero('water_a');
      expect(assign.ok, isTrue);
      expect(assign.progress.partyCount(RuneElement.water), 1);

      final un = assign.progress.tryUnassignHero('water_a');
      expect(un.ok, isTrue);
      expect(un.progress.partyCount(RuneElement.water), 0);
      expect(un.progress.ownedCount(RuneElement.water), 1);

      // 재편성
      final re = un.progress.tryAssignHero('water_a');
      expect(re.ok, isTrue);
      expect(re.progress.partyCount(RuneElement.water), 1);

      // 파티 0 → 해제 불가
      expect(re.progress.tryUnassignHero('grass_a').ok, isFalse);
    });

    test('recordTutorialDone (RPT-406)', () {
      expect(RuneMeta.initial().tutorialCompleted, isFalse);
      expect(RuneMeta.initial().recordTutorialDone().tutorialCompleted, isTrue);
    });
  });

}