/// RuneElement 룬 아이콘 시트 소스 좌표 검증.
///
/// assets/images/runes/rune_row4.png (512×59, 원본 5행 시트의 4행 추출)의 6개 아이콘을
/// 각 요소가 올바르게 참조하는지 인라인 상수만으로 확인한다 (테스트/실기기 공용).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_puzzle_tactics/game/rune.dart';

void main() {
  test('RuneElement 6종 모두 시트 내부에 유일한 아이콘 소스 X를 가진다', () {
    expect(RuneElement.values, hasLength(6));

    final xs = RuneElement.values.map((e) => e.spriteSrcX).toList();
    expect(
      xs.toSet(),
      hasLength(6),
      reason: '아이콘 소스 X 좌표가 중복되면 서로 다른 룬이 같은 자산을 참조함',
    );

    for (final e in RuneElement.values) {
      // 아이콘이 시트 폭 안쪽에 완전히 포함되는지 (오른쪽 넘침 방지).
      expect(e.spriteSrcX, greaterThanOrEqualTo(0));
      expect(
        e.spriteSrcX + RuneElement.runeSpriteIconWidth,
        lessThanOrEqualTo(RuneElement.runeSpriteWidth),
        reason: '${e.name} 아이콘이 시트를 벗어남',
      );
    }

    // 아이콘 높이가 시트 높이 안쪽인지 (위/아래 넘침 방지).
    expect(
      RuneElement.runeSpriteIconHeight,
      lessThanOrEqualTo(RuneElement.runeSpriteHeight),
    );
  });
}