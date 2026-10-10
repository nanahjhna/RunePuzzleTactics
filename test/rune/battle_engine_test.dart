import 'dart:math' as math;

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_helpers.dart';

void main() {
  // 바닥 FFF → 유효 Swap 준비 보드 (6×6, 바닥 행 y=5)
  PuzzleBoard swapTargetBoard() {
    final board = boardFromRows(cleanRows);
    board.setIndex(idx(board, 1, 5), rune(RuneElement.fire));
    board.setIndex(idx(board, 2, 5), rune(RuneElement.fire));
    board.setIndex(idx(board, 3, 5), rune(RuneElement.water));
    board.setIndex(idx(board, 3, 4), rune(RuneElement.fire));
    return board;
  }

  PuzzleMove bottomSwap(BattleEngine b) =>
      PuzzleMove(idx(b.state.board, 3, 4), idx(b.state.board, 3, 5));

  group('턴 플로우 (RPT-97 ~ RPT-102)', () {
    test('PLAN → ACTION → 유효 Swap → Resolve → Monster Turn', () {
      final battle = battleWithBoard(board: swapTargetBoard());
      battle.startBattle();
      expect(battle.state.phase, BattlePhase.plan);

      battle.onFirstTouch();
      expect(battle.state.phase, BattlePhase.action);

      battle.onDragStart(idx(battle.state.board, 3, 4));
      expect(battle.state.phase, BattlePhase.inputResolving);

      battle.onDragEnd(bottomSwap(battle));
      expect(battle.state.phase, BattlePhase.plan); // Monster Turn 후 새 턴
      expect(battle.monsterHp, lessThan(1000)); // Fire 3매치 = 100 × 0.8 = 80 이상
      expect(battle.partyHp, 91); // 몬스터 반격 9 (감쇄형, RPT-113)
      // 몬스터 턴 연출 종료 후 다음 플레이어 턴을 연다.
      battle.startPlayerTurn();
      expect(battle.state.phase, BattlePhase.plan);
    });

    test('적의 첫 공격 후 두 번째 플레이어 턴에도 유효 Swap이 가능하다', () {
      final battle = battleWithBoard(
        board: swapTargetBoard(),
        rng: math.Random(11),
      );
      battle.startBattle();
      battle.onDragStart(idx(battle.state.board, 3, 4));
      battle.onDragEnd(bottomSwap(battle));
      expect(battle.state.phase, BattlePhase.plan);
      expect(battle.partyHp, 91); // 몬스터 반격 9 (감쇄형)
      expect(battle.engine.hasAvailableMove(battle.state.board), isTrue);

      PuzzleMove? secondMove;
      for (
        var from = 0;
        from < PuzzleBoard.size && secondMove == null;
        from++
      ) {
        for (final to in [
          if (from % PuzzleBoard.cols < PuzzleBoard.cols - 1) from + 1,
          if (from ~/ PuzzleBoard.cols < PuzzleBoard.rows - 1)
            from + PuzzleBoard.cols,
        ]) {
          final probe = battle.state.board.clone();
          if (!battle.engine.resolveSwap(probe, from: from, to: to).isEmpty) {
            secondMove = PuzzleMove(from, to);
            break;
          }
        }
      }
      expect(secondMove, isNotNull);

      battle.onDragStart(secondMove!.from);
      battle.onDragEnd(secondMove);
      expect(
        battle.lastResolve?.outcome,
        isNot(BattleResolveOutcome.invalidSwap),
      );
      expect(battle.state.phase, BattlePhase.plan);
      // 몬스터 반격 2회 (매 턴 9씩) — 감쇄형이라 매 턴 ATK 10 에서 9 로 깎인다.
      expect(battle.partyHp, 82);
    });

    test('Monster HP 0 → Victory (RPT-146~147)', () {
      // 몬스터는 무속성이지만 이 스테이지의 약점은 Fire(×1.5)다.
      // Fire 매칭 데미지 = fire_a ATK 15 × 콤보 × 1.5 = 22.5 → 23.
      final battle = battleWithBoard(
        board: swapTargetBoard(),
        stage: testStage(monsterHp: 80),
      );
      battle.startBattle();
      battle.onFirstTouch();
      battle.onDragEnd(bottomSwap(battle));
      expect(battle.state.phase, BattlePhase.victory);
    });

    test('endTurn(포기) → Monster Turn', () {
      final battle = battleWithBoard(board: boardFromRows(cleanRows));
      battle.startBattle();
      battle.onFirstTouch();
      battle.endTurn();
      expect(battle.state.phase, BattlePhase.plan);
      expect(battle.partyHp, 91); // 몬스터 반격 9 (감쇄형)
    });

    test('일시정지/재개 후에도 현재 플레이어 턴을 유지한다', () {
      final battle = battleWithBoard(board: swapTargetBoard());
      battle.startBattle();
      battle.onFirstTouch();
      battle.pause();
      expect(battle.state.paused, isTrue);
      battle.resume();
      expect(battle.state.paused, isFalse);
      expect(battle.state.phase, BattlePhase.action);
      battle.onDragEnd(bottomSwap(battle));
      expect(battle.partyHp, 91); // 몬스터 반격 9 (감쇄형)
    });

    test('retreat → Retreat 단계', () {
      final battle = battleWithBoard(board: boardFromRows(cleanRows));
      battle.retreat();
      expect(battle.state.phase, BattlePhase.retreat);
    });
  });

  group('제한시간 없는 플레이어 턴', () {
    test('스킬은 heroId 기준이며 전 영웅이 가진다 (Light 포함)', () {
      // 스킬은 속성이 아니라 영웅 단위다. 미등록 heroId 만 null.
      expect(HeroSkills.specFor(RuneElement.light.name), isNull);
      for (final hero in HeroPool.heroes) {
        expect(
          HeroSkills.hasSkill(hero.heroId),
          isTrue,
          reason: '${hero.heroId} 에 스킬이 없다',
        );
      }
    });

    test('요소마다 스킬이 하나씩 정해진다 (같은 요소는 같은 효과)', () {
      // 요소별 스킬 재설계: 5요소 = 5효과. 같은 요소의 4명은 같은 효과를 쓴다 —
      // 차이는 수치가 아니라 **보드 상태**(몇 칸이 바뀌었는지)에서 나온다.
      for (final element in RuneElement.values) {
        if (element == RuneElement.black) continue;
        final specs = [
          for (final h in HeroPool.forElement(element))
            HeroSkills.specFor(h.heroId)!,
        ];
        expect(specs, isNotEmpty, reason: '$element 영웅이 없다');
        expect(
          specs.map((s) => s.effect).toSet(),
          hasLength(1),
          reason: '$element 의 4명이 서로 다른 효과를 갖는다',
        );
        expect(specs.first.element, element);
      }
      // 요소 5개 = 효과 5개가 일대일로 대응한다.
      expect(HeroSkillEffect.values, hasLength(5));
      expect(HeroSkillEffect.values.map((e) => e.needsTarget).toSet(), {
        true,
        false,
      });
    });

    test('무효 Swap은 턴을 소비하지 않고 플레이어가 계속 조작할 수 있다', () {
      final battle = battleWithBoard(board: boardFromRows(cleanRows));
      battle.startBattle();
      battle.onFirstTouch();
      battle.onDragStart(idx(battle.state.board, 0, 0));
      battle.onDragEnd(
        PuzzleMove(
          idx(battle.state.board, 0, 0),
          idx(battle.state.board, 1, 0),
        ),
      ); // 무효

      expect(battle.state.phase, BattlePhase.action);
      expect(battle.monsterHp, 1000); // 데미지 없음
      expect(battle.partyHp, 100); // 턴 미소비 → Monster Attack 없음
    });
  });

  group('Boss (RPT-145)', () {
    test('카운트다운 1 → Boss Ultimate → Party HP 0 → Defeat', () {
      final battle = battleWithBoard(
        board: boardFromRows(cleanRows),
        stage: testStage(
          type: StageType.boss,
          bossCountdown: 1,
          monsterAttack: 0,
          monsterHp: 100000,
        ),
      );
      battle.startBattle();
      battle.onFirstTouch();
      battle.endTurn(); // Player 포기
      expect(battle.state.bossCountdown, 0);
      expect(battle.partyHp, 0);
      expect(battle.state.phase, BattlePhase.defeat);
    });

    test('정상 어택은 매 턴 Countdown 감소 후 일반 공격', () {
      final battle = battleWithBoard(
        board: boardFromRows(cleanRows),
        stage: testStage(
          type: StageType.boss,
          bossCountdown: 3,
          monsterAttack: 10,
          monsterHp: 100000,
        ),
      );
      battle.startBattle();
      battle.onFirstTouch();
      battle.endTurn();
      expect(battle.state.bossCountdown, 2);
      expect(battle.partyHp, 91); // 몬스터 반격 9 (감쇄형)
      expect(battle.state.phase, BattlePhase.plan);
    });
  });

  group('요소별 스킬 (Fire/Water/Grass/Light/Poison)', () {
    /// [heroId] 한 명만 편성한 전투를 만든다. 요소 스킬의 수치가 "파티 구성"과
    /// 무관해야(고정 피해) 이 헬퍼로 그게 무관함을 함께 검증할 수 있다.
    BattleEngine singleHeroBattle(
      String heroId, {
      PuzzleBoard? board,
      StageConfig? stage,
    }) => battleWithBoard(
      board: board ?? boardFromRows(cleanRows),
      stage: stage,
      roster: HeroRoster.fromIds([heroId], ownedIds: [heroId]),
    );

    group('Fire — 고른 색의 룬을 전량 불로', () {
      test('누른 칸과 같은 색의 룬이 보드 전부 바뀐다', () {
        final board = boardFromRows(cleanRows);
        final waterBefore = board.indicesOf(RuneElement.water).length;
        expect(waterBefore, 9);

        final battle = singleHeroBattle('fire_a', board: board);
        battle.startBattle();
        battle.onFirstTouch();

        expect(battle.useHeroSkill('fire_a', target: idx(board, 1, 0)), isTrue);
        expect(board.indicesOf(RuneElement.water), isEmpty);
        expect(
          board.indicesOf(RuneElement.fire).length,
          waterBefore,
          reason: '다른 색 룬까지 불로 바뀌면 안 된다',
        );
        expect(board.indicesOf(RuneElement.grass).length, 10);
        // Fire 스킬은 변환 직후 성립한 매칭을 연쇄로 잇는다.
        // cleanRows 에서 Water 9개를 전부 Fire 로 바꾸면 가로/세로 매치가 생긴다.
        expect(battle.lastResolve!.heroSkillEvents.single.amount, waterBefore);
      });

      test('빈칸·Black·이미 불인 칸은 지정할 수 없다', () {
        final board = boardFromRows(cleanRows);
        board.setIndex(
          idx(board, 5, 5),
          const BoardTile.rune(RuneElement.black),
        );
        board.setIndex(
          idx(board, 0, 0),
          const BoardTile.rune(RuneElement.fire),
        );
        board.setIndex(idx(board, 4, 5), null);

        final battle = singleHeroBattle('fire_a', board: board);
        battle.startBattle();
        final spec = HeroSkills.specFor('fire_a')!;
        expect(battle.isValidSkillTarget(spec, idx(board, 1, 0)), isTrue);
        expect(
          battle.isValidSkillTarget(spec, idx(board, 5, 5)),
          isFalse,
        ); // Black
        expect(battle.isValidSkillTarget(spec, idx(board, 0, 0)), isFalse); // 불
        expect(
          battle.isValidSkillTarget(spec, idx(board, 4, 5)),
          isFalse,
        ); // 빈칸

        // 유효하지 않은 지정은 턴을 소비하지 않는다 (조준 취소 경로).
        battle.onFirstTouch();
        expect(
          battle.useHeroSkill('fire_a', target: idx(board, 5, 5)),
          isFalse,
        );
        // 스테이지당 1회 규칙: 무효 지정으로는 영웅의 스킬이 소모되지 않는다.
        expect(battle.state.units.first.skillUsed, isFalse);
        expect(battle.monsterHp, 1000);
      });
    });

    group('Water — 파란 룬 개수 × 10 피해', () {
      test('개수만큼 10 배의 고정 피해를 준다 (상성 미적용)', () {
        final board = boardFromRows(cleanRows);
        final battle = singleHeroBattle('water_a', board: board);
        battle.startBattle();
        battle.onFirstTouch();

        final waterCount = board.indicesOf(RuneElement.water).length;
        expect(waterCount, 9);
        expect(battle.useHeroSkill('water_a'), isTrue);
        // 곧바로 몬스터 턴이 돌아 독 틱은 없지만 반격은 온다.
        expect(battle.monsterHp, 1000 - waterCount * 10);
        expect(battle.lastResolve!.heroSkillEvents.single.amount, 90);
      });

      test('파란 룬이 0 개면 피해도 0 이다', () {
        final board = boardFromRows(cleanRows);
        for (final i in board.indicesOf(RuneElement.water).toList()) {
          board.setIndex(i, const BoardTile.rune(RuneElement.poison));
        }
        final battle = singleHeroBattle('water_a', board: board);
        battle.startBattle();
        battle.onFirstTouch();
        expect(battle.useHeroSkill('water_a'), isTrue);
        expect(battle.lastResolve!.heroSkillEvents.single.amount, 0);
        expect(battle.monsterHp, 1000);
      });
    });

    group('Grass — 초록 룬 개수 × 10 회복', () {
      test('합산 회복량을 살은 영웅에게 나눠 주고 최대 HP 를 넘지 않는다', () {
        final board = boardFromRows(cleanRows);
        final grassCount = board.indicesOf(RuneElement.grass).length;
        expect(grassCount, 10);

        final battle = singleHeroBattle('grass_a', board: board);
        battle.startBattle();
        battle.onFirstTouch();

        final hpBefore = battle.partyHp;
        battle.state.units.first.applyDamage(60);

        expect(battle.useHeroSkill('grass_a'), isTrue);
        // 회복 풀 100 을 주지만 최대 HP(100)를 넘길 수 없다.
        expect(battle.lastResolve!.heroSkillEvents.single.amount, 60);
        expect(battle.partyHp, hpBefore);
      });
    });

    group('Light — 지정 칸 3×3 폭발', () {
      test('중심 + 주변 8칸을 제거하고 폭발 오브와 같은 영역 규칙을 쓴다', () {
        final board = boardFromRows(cleanRows);
        final battle = singleHeroBattle('light_a', board: board);
        battle.startBattle();
        battle.onFirstTouch();

        final center = idx(board, 2, 2);
        expect(battle.useHeroSkill('light_a', target: center), isTrue);
        final event = battle.lastResolve!.heroSkillEvents.single;
        expect(event.cells, PuzzleBoard.area3x3(center));
        expect(event.amount, 9); // 중앙 9칸
        // 제거가 일어났으므로 보드는 반드시 달라진다.
        expect(
          boardToString(board),
          isNot(boardToString(boardFromRows(cleanRows))),
        );
      });

      test('모서리는 4칸, 가장자리는 6칸으로 경계를 잘라낸다', () {
        final battle = singleHeroBattle('light_a');
        battle.startBattle();
        expect(
          PuzzleBoard.area3x3(idx(battle.state.board, 0, 0)),
          hasLength(4),
        );
        expect(
          PuzzleBoard.area3x3(idx(battle.state.board, 2, 0)),
          hasLength(6),
        );
        expect(
          PuzzleBoard.area3x3(idx(battle.state.board, 2, 2)),
          hasLength(9),
        );
      });

      test('Black 룬도 지정할 수 있다 (유일한 제거 수단)', () {
        final board = boardFromRows(cleanRows);
        final blackAt = idx(board, 2, 2);
        board.setIndex(blackAt, const BoardTile.rune(RuneElement.black));

        final battle = singleHeroBattle('light_a', board: board);
        battle.startBattle();
        final spec = HeroSkills.specFor('light_a')!;
        expect(battle.isValidSkillTarget(spec, blackAt), isTrue);

        battle.onFirstTouch();
        expect(battle.useHeroSkill('light_a', target: blackAt), isTrue);
        expect(
          battle.lastResolve!.heroSkillEvents.single.cells,
          contains(blackAt),
        );
      });
    });

    group('Poison — 독 스택 지속 피해', () {
      test('독 룬 개수만큼 스택을 붙이고 매 몬스터 턴 스택당 5 를 깎는다', () {
        final board = boardFromRows(cleanRows);
        final poisonCount = board.indicesOf(RuneElement.poison).length;
        expect(poisonCount, 8);

        final battle = singleHeroBattle('poison_a', board: board);
        battle.startBattle();
        battle.onFirstTouch();

        expect(battle.useHeroSkill('poison_a'), isTrue);
        expect(battle.state.poisonStacks, poisonCount);
        expect(battle.state.poisonPerStack, 5);
        // 스택이 붙자마자 같은 턴의 몬스터 턴에서 첫 틱이 돈다.
        expect(battle.monsterHp, 1000 - poisonCount * 5);
        expect(battle.lastResolve!.finalState.monsterPoisonStacks, poisonCount);

        final ticks = battle.lastResolve!.monsterHits
            .where((h) => h.source == DamageSource.poisonTick)
            .toList();
        expect(ticks, hasLength(1));
        expect(ticks.single.damage, poisonCount * 5);
        expect(battle.lastResolve!.summedMonsterDamage, poisonCount * 5);

        // 스택은 소진되지 않는다 — 시간이 갈수록 누적 피해가 커진다.
        battle.endTurn();
        expect(battle.state.poisonStacks, poisonCount);
        expect(battle.monsterHp, 1000 - poisonCount * 5 * 2);
      });

      test('상한 10 을 넘겨 쌓이지 않는다', () {
        final board = boardFromRows(cleanRows);
        for (var i = 0; i < PuzzleBoard.size; i++) {
          board.setIndex(i, const BoardTile.rune(RuneElement.poison));
        }
        final battle = battleWithBoard(
          board: board,
          stage: testStage(monsterHp: 1000000, monsterAttack: 0),
          roster: HeroRoster.fromIds(
            ['poison_a'],
            ownedIds: ['poison_a'],
          ),
        );
        battle.startBattle();
        battle.onFirstTouch();
        expect(battle.useHeroSkill('poison_a'), isTrue);
        expect(battle.state.poisonStacks, HeroSkills.maxPoisonStacks);
      });
    });

    group('표적 지정 (조준)', () {
      test('대상 없이 조준 스킬을 쓰면 false — 턴을 소비하지 않는다', () {
        final battle = singleHeroBattle('fire_a');
        battle.startBattle();
        battle.onFirstTouch();
        expect(battle.useHeroSkill('fire_a'), isFalse);
        expect(battle.state.units.first.skillUsed, isFalse);
        expect(battle.monsterHp, 1000);
      });

      test('즉시 발동 스킬은 대상 없이 바로 쓴다', () {
        final battle = singleHeroBattle('water_a');
        battle.startBattle();
        battle.onFirstTouch();
        expect(battle.useHeroSkill('water_a'), isTrue);
        expect(battle.state.units.first.skillUsed, isTrue);
      });

      test('스테이지당 1회 — 다음 턴에도 같은 영웅은 못 쓴다', () {
        final battle = singleHeroBattle('water_a');
        battle.startBattle();
        battle.onFirstTouch();
        expect(battle.useHeroSkill('water_a'), isTrue);
        final monsterHpAfterSkill = battle.monsterHp;

        // 턴을 여러 번 넘겨도 영웅별 스킬은 소진된 채로 남는다.
        for (var turn = 0; turn < 3; turn++) {
          battle.endTurn();
          expect(battle.canUseHeroSkill('water_a'), isFalse);
          expect(battle.useHeroSkill('water_a'), isFalse);
        }
        // 잠금이 유지되어 몬스터 HP 는 스킬 피해분 그대로다.
        expect(battle.monsterHp, lessThanOrEqualTo(monsterHpAfterSkill));
        expect(battle.state.units.first.skillUsed, isTrue);
      });

      test('서로 다른 영웅은 각자 스킬을 쓸 수 있다', () {
        final battle = battleWithBoard(
          board: boardFromRows(cleanRows),
          stage: testStage(monsterHp: 100000, monsterAttack: 0),
          roster: HeroRoster.fromIds(
            ['water_a', 'grass_a'],
            ownedIds: ['water_a', 'grass_a'],
          ),
        );
        battle.startBattle();
        battle.onFirstTouch();
        expect(battle.useHeroSkill('water_a'), isTrue);
        expect(battle.canUseHeroSkill('water_a'), isFalse);
        expect(battle.canUseHeroSkill('grass_a'), isTrue);
      });

      test('하이라이트 대상 목록과 유효 판정이 같은 규칙을 쓴다', () {
        final board = boardFromRows(cleanRows);
        board.setIndex(
          idx(board, 5, 5),
          const BoardTile.rune(RuneElement.black),
        );
        final battle = singleHeroBattle('fire_a', board: board);
        battle.startBattle();
        final spec = HeroSkills.specFor('fire_a')!;
        final targets = battle.validSkillTargets(spec);
        expect(targets, isNotEmpty);
        for (final i in targets) {
          expect(battle.isValidSkillTarget(spec, i), isTrue);
        }
        expect(targets, isNot(contains(idx(board, 5, 5))));
      });
    });
  });
}

int idx(PuzzleBoard b, int x, int y) => b.indexAt(x, y);
BoardTile rune(RuneElement e) => BoardTile.rune(e);
