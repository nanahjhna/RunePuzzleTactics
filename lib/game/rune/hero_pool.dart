/// Hero Pool 정의 — 3-재화 설계(영웅 재화) + 랜덤 영입(뽑기) 기반 (RPT-306 개편)
///
/// - 5 속성 × 1 영웅 = 5명. id는 `{element}_a` (fire_a … poison_a).
/// - 해금 스테이지: a → 1 (nextStage 기준). 시작부터 뽑기 풀에 포함된다.
/// - 순서가 곧 **등급**이다: 1→R ([RuneHeroDef.rarity]).
///   등급은 현재 ★ 1단계뿐이라 영웅 5명 모두 R 이다. 2성 이상을 추가하면
///   2→SR, 3→SSR, 4→UR 로 자동 확장된다 (b/c/d 영웅도 함께 추가).
/// - **스탯은 영웅마다 다르다** ([_stats] 테이블). 딜러형은 ATK 로, 탱커형은
///   DEF·HP 로, 서포터형은 중간값으로 방향을 준다.
/// - 스킬은 heroId 단위다 ([HeroSkills]) — 요소별 1종이며, 같은 요소의 영웅은
///   같은 스킬을 쓴다.
/// - **초상화는 속성 단위**다 ([_portraits]). 같은 속성 영웅은 같은 그림을
///   쓰며, 정사각형 슬롯용 얼굴 크롭과 세로 슬롯용 전신을 따로 둔다.
library;

import 'hero_rarity.dart';
import 'rune_element.dart';

/// 영웅 1명의 정의.
class RuneHeroDef {
  const RuneHeroDef({
    required this.heroId,
    required this.element,
    required this.recruitOrder,
    required this.recruitCost,
    required this.unlockStage,
    this.portraitAssetPath, // 정사각형 슬롯용 얼굴 크롭 초상화 (null 이면 속성 이모지)
    this.portraitFullAssetPath, // 세로 슬롯용 전신 초상화 (null 이면 [portraitAssetPath])
    this.hp = 100,
    this.attack = 15,
    this.defense = 8,
  });

  /// 전역 고유 id (예: 'fire_a', 'water_a').
  final String heroId;

  /// 속성.
  final RuneElement element;

  /// 같은 속성 내 영입 순서 (1=첫 영웅).
  final int recruitOrder;

  /// 영입 비용 (Hero Currency). 스타터는 0.
  final int recruitCost;

  /// 영입 해금에 필요한 최소 nextStage (1이면 시작부터 영입 가능).
  final int unlockStage;

  /// 정사각형 슬롯용 얼굴 크롭 초상화. null이면 속성 이모지로 폴백.
  final String? portraitAssetPath;

  /// 세로 슬롯(전투 HUD)용 전신 초상화.
  ///
  /// 슬롯 종횡비(0.46~0.65)가 전신 이미지(0.67)와 비슷해 가로 크롭이 거의 없다.
  /// null이면 [portraitAssetPath] 로 폴백한다.
  final String? portraitFullAssetPath;

  /// 최대 HP 기여분. 파티 최대 HP 에 합산된다.
  final int hp;

  /// 공격력 기여분. 이 영웅의 개인 공격력이 되며(파티 보너스 분배 반영),
  /// 매칭 데미지의 밑인 살아있는 영웅 공격력 합에 포함된다.
  final int attack;

  /// 방어력 기여분. 이 영웅이 몬스터 반격을 받을 때 쓰이는 개인 방어력이 된다.
  final int defense;

  int get atk => attack;
  int get def => defense;

  /// 초기 등급. 영입 순서가 곧 등급이다 (1→R, 2→SR …).
  HeroRarity get rarity => HeroRarity.forRecruitOrder(recruitOrder);

  /// 기본 지급 스타터 여부.
  bool get isStarter => recruitCost == 0;
}

/// 5명 영웅 풀 + 조회 헬퍼.
class HeroPool {
  HeroPool._();

  /// 순서별 영입 비용(영웅 재화) — index = recruitOrder - 1.
  ///
  /// 현재는 순서 1(=a)만 존재하므로 항목이 하나다. b/c/d 를 되살리면 배열만
  /// 늘리면 된다 (해금 스테이지 배열도 함께).
  static const List<int> recruitCosts = [500];

  /// 순서별 해금 스테이지 — index = recruitOrder - 1.
  static const List<int> unlockStages = [1];

  /// 초상화 에셋 매핑 — **속성 단위** (heroId 가 아니라).
  ///
  /// `face` = 256x256 정사각형 얼굴 크롭. 정사각형 슬롯(영웅도감 30px, 파티
  /// 그리드 52px, 가챠 결과 34px, 히어로 카드)에 쓰인다.
  /// `full` = 409x610 전신. 세로 슬롯(전투 HUD 60x96~136)에 쓰인다.
  ///
  /// 영웅 전원이 속성별로 이 이미지를 공유한다. 스킬이 heroId 단위인 것과
  /// 달리 초상화는 속성 규칙이므로 시너지 축과 같은 granularity 다. 매핑이
  /// 없으면 속성 이모지로 폴백한다.
  static const Map<RuneElement, ({String face, String full})> _portraits = {
    RuneElement.fire: (
      face: 'assets/images/hero/fire_face.png',
      full: 'assets/images/hero/fire_full.png',
    ),
    RuneElement.grass: (
      face: 'assets/images/hero/grass_face.png',
      full: 'assets/images/hero/grass_full.png',
    ),
    RuneElement.water: (
      face: 'assets/images/hero/water_face.png',
      full: 'assets/images/hero/water_full.png',
    ),
    RuneElement.light: (
      face: 'assets/images/hero/light_face.png',
      full: 'assets/images/hero/light_full.png',
    ),
    RuneElement.poison: (
      face: 'assets/images/hero/poison_face.png',
      full: 'assets/images/hero/poison_full.png',
    ),
  };

  /// **피격 순간** 전신 이미지 — [HeroHitFlash] 가 초상화 위에 겹친다.
  ///
  /// 평상시 초상화 위에 순간적으로 겹쳐 "데미지 입은 얼굴" 을 보여준다.
  /// 규격이 [RuneHeroDef.portraitFullAssetPath] 와 동일(408×612)하므로
  /// 프레이밍이 어긋나지 않는다.
  static const Map<RuneElement, String> _damagePortraits = {
    RuneElement.fire: 'assets/images/hero/fire_damage_full.png',
    RuneElement.grass: 'assets/images/hero/grass_damage_full.png',
    RuneElement.water: 'assets/images/hero/water_damage_full.png',
    RuneElement.light: 'assets/images/hero/light_damage_full.png',
    RuneElement.poison: 'assets/images/hero/poison_damage_full.png',
  };
  static const String _defaultDamagePortrait =
      'assets/images/hero/fire_damage_full.png';

  /// [RuneElement] 에 해당하는 피격 연출 전신 이미지 경로를 반환한다.
  ///
  /// 매핑이 없으면 기본값인 `fire_damage_full.png` 를 되돌린다.
  static String damagePortraitFor(RuneElement e) =>
      _damagePortraits[e] ?? _defaultDamagePortrait;

  /// 영웅별 개별 스탯 (heroId -> (hp, atk, def)).
  ///
  /// [RuneHeroDef] 기본값을 쓰는 영웅은 맵에 없어도 된다. 값은
  /// RuneHeroDef 생성자에 그대로 주입된다.
  ///
  /// 역할 배분 원칙:
  /// - **딜러** — ATK 높고 DEF 낮음. 그 색 룬의 매칭 데미지 밑이
  ///   `attackForElement` 로 합쳐진다.
  /// - **탱커** — DEF 높고 ATK 낮음. 몬스터 반격이 `ATK × 100/(100+DEF)` 라
  ///   DEF 가 비례 감쇄로 작동하므로, 높은 DEF 가 확실히 버틴다.
  /// - **서포터** — 중간값. 스킬(회복/방어막/변환)에서 기여한다.
  static const Map<String, ({int hp, int atk, int def})> _stats = {
    // ── Fire ──
    'fire_a': (hp: 100, atk: 15, def: 8), // R   딜러
    // ── Water ──
    'water_a': (hp: 110, atk: 13, def: 9), // R   서포터
    // ── Grass ──
    'grass_a': (hp: 115, atk: 12, def: 10), // R   서포터
    // ── Light ──
    'light_a': (hp: 105, atk: 13, def: 9), // R   서포터
    // ── Poison ──
    'poison_a': (hp: 95, atk: 16, def: 6), // R   딜러
  };

  static final List<RuneHeroDef> heroes = _build();

  static List<RuneHeroDef> _build() {
    final list = <RuneHeroDef>[];
    for (final e in RuneElement.normal) {
      for (var order = 1; order <= recruitCosts.length; order++) {
        final id = '${e.name}_${String.fromCharCode(96 + order)}';
        final s = _stats[id];
        list.add(
          RuneHeroDef(
            heroId: id,
            element: e,
            recruitOrder: order,
            recruitCost: e == RuneElement.fire && order == 1
                ? 0 // 스타터: fire_a 무료
                : recruitCosts[order - 1],
            unlockStage: unlockStages[order - 1],
            // 초상화는 속성 단위 공유 — heroId 가 아니라 element 로 조회한다.
            portraitAssetPath: _portraits[e]?.face,
            portraitFullAssetPath: _portraits[e]?.full,
            hp: s?.hp ?? 100,
            attack: s?.atk ?? 15,
            defense: s?.def ?? 8,
          ),
        );
      }
    }
    return List.unmodifiable(list);
  }

  /// 기본 지급 스타터 (Fire Hero #1).
  static RuneHeroDef get starter => byId('fire_a')!;

  /// id로 조회. 존재하지 않으면 null.
  static RuneHeroDef? byId(String heroId) {
    for (final h in heroes) {
      if (h.heroId == heroId) return h;
    }
    return null;
  }

  /// 속성별 영웅 목록 (recruitOrder 오름차순).
  static List<RuneHeroDef> forElement(RuneElement e) =>
      List.unmodifiable(heroes.where((h) => h.element == e).toList());

  /// ★ 1성 영웅 — 파티 화면 영웅도감이 노출하는 목록 (속성당 1명, 총 5명).
  ///
  /// 현재 로스터는 속성별 a 영웅 1명뿐이라 이 목록은 [heroes] 와 같다. b/c/d
  /// 영웅을 되살리면 이 getter 는 "속성별 1번 영웅"만 돌려주는 필터로 다시
  /// 좁혀진다 (도감은 대표 영웅만 노출).
  ///
  /// 필터 기준은 등급이 아니라 **영입 순서**다. 등급 enum 에 2성이 추가되기
  /// 전까지 `heroes.where((h) => h.rarity == HeroRarity.r)` 는 [HeroRarity] 의
  /// 범위 보정 때문에 2/3/4성까지 전부 `r` 로 떨어뜨려 아무것도 거르지 못한다.
  static List<RuneHeroDef> get oneStarHeroes => List.unmodifiable(
    heroes.where((h) => h.recruitOrder == 1).toList(),
  );
}
