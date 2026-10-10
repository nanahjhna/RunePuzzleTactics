import 'dart:math';

import 'package:rune_puzzle_tactics/game/rune.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StageGenerator (RPT-172 ~ RPT-177)', () {
    test('타입 규칙: %10 Boss, %5 Elite (RPT-174)', () {
      expect(StageGenerator.typeFor(1), StageType.normal);
      expect(StageGenerator.typeFor(4), StageType.normal);
      expect(StageGenerator.typeFor(5), StageType.elite);
      expect(StageGenerator.typeFor(10), StageType.boss);
      expect(StageGenerator.typeFor(11), StageType.normal);
      expect(StageGenerator.typeFor(15), StageType.elite);
      expect(StageGenerator.typeFor(20), StageType.boss);
    });

    test('상성은 스테이지 단위로 배정된다 (약점 ×1.5 / 열세 ×0.5)', () {
      // 몬스터 자체는 무속성이므로 상성은 "몇 단계 몬스터인가"가 아니라
      // "이 스테이지가 어느 색에 약한가"로 정한다.
      for (final n in const [1, 3, 9, 12, 25]) {
        final weak = StageGenerator.weakElementFor(n);
        final resist = StageGenerator.resistElementFor(n);
        expect(weak, isNot(resist), reason: 'stage $n');
        expect(StageGenerator.weakElementFor(n), weak);
        expect(StageGenerator.resistElementFor(n), resist);
      }
    });

    test('약점과 열세는 항상 5속성 안에 있다', () {
      for (var n = 1; n <= 40; n++) {
        expect(
          RuneElement.normal,
          contains(StageGenerator.weakElementFor(n)),
          reason: 'stage $n 약점',
        );
        expect(
          RuneElement.normal,
          contains(StageGenerator.resistElementFor(n)),
          reason: 'stage $n 열세',
        );
      }
    });

    test('몬스터 이름/서브타틀은 스테이지 번호 기반 (5단계마다 교체)', () {
      expect(StageGenerator.monsterNameFor(1), 'Cave Slime');
      expect(StageGenerator.monsterNameFor(6), 'Stone Maw');
      expect(StageGenerator.monsterNameFor(21), 'Cave Slime');
      // 종류 접두는 별도 규칙. 이름도 함께 교체된다 — 10스테이지의 이름 인덱스는
      // (10-1)~/5 = 1 이므로 'Stone Maw' 다.
      expect(StageGenerator.monsterNameFor(5), 'Elite Cave Slime');
      expect(StageGenerator.monsterNameFor(10), 'Elder Stone Maw');
    });

    test('결정론적 생성 + 스테이지별 확장 (RPT-172, 176)', () {
      final g = StageGenerator();
      final s3a = g.generate(3);
      final s3b = g.generate(3);
      expect(s3a.monsterHp, s3b.monsterHp);
      expect(s3a.stageNumber, 3);
      expect(s3a.type, StageType.normal);
      expect(s3a.weakElement, StageGenerator.weakElementFor(3));
      expect(s3a.resistElement, StageGenerator.resistElementFor(3));
      expect(s3a.maxBlackOnBoard, 6);

      // HP/ATK는 증가곡선 (RPT-176)
      expect(g.generate(4).monsterHp, greaterThan(g.generate(3).monsterHp));
      expect(
        g.generate(4).monsterAttack,
        greaterThanOrEqualTo(g.generate(3).monsterAttack),
      );
    });

    test('Boss: HP ×2.5, 카운트다운 3, Black 허용 7 (RPT-145, RPT-198)', () {
      final g = StageGenerator();
      final normal10 = (g.baseHp * pow(1 + 10 * 0.08, 1.15)).round();
      final boss = g.generate(10);
      expect(boss.type, StageType.boss);
      expect(boss.monsterHp, (normal10 * 2.5).round());
      expect(boss.bossCountdown, 3);
      expect(boss.maxBlackOnBoard, 7);
    });

    test('골드 보상 증가', () {
      final g = StageGenerator();
      expect(g.generate(5).goldReward, greaterThan(g.generate(1).goldReward));
    });
  });
}
