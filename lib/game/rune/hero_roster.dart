/// 영웅 파티 관리 — **heroId 단위** (영웅 단위 스탯/스킬 분리의 전제 조건)
///
/// 이전 구현은 `Map<RuneElement, int>` 로 속성별 "개수"만 저장했다. 그래서
/// 어떤 영웅을 소유해도 엔진에는 속성 개수로만 들어가고, 전투가 그 영웅의
/// 스탯/스킬을 써야 하는지 알 수 없었다. 이 클래스는 heroId 집합을 정본으로 삼는다.
///
/// - 보유(Owned) / 파티(Party)를 id 기준으로 구분한다.
/// - 속성별 집계([partyCount])는 UI 표시용이다. 데미지 배율은 여기서 나오지
///   않고, 같은 색 영웅의 **공격력 합**이 그대로 데미지 밑이 된다.
/// - 편성 순서는 저장된 순서대로 유지한다(재시작해도 슬롯이 흔들리지 않는다).
library;

import 'hero_pool.dart';
import 'rune_element.dart';

/// 영웅 보유(Owned) 풀과 현재 파티(Party)를 heroId 단위로 관리한다.
class HeroRoster {
  /// 파티 최대 인원 (RPT-21, RPT-289)
  ///
  /// 드래곤퀘스트식 구성으로 4인. 정원이 바뀌면 이전 저장 데이터에 남은 초과분은
  /// `RuneProgress` 생성자가 `take()` 로 잘라낸다(Owned 는 유지).
  static const int maxPartySize = 4;

  /// 보유 풀 (heroId 집합).
  final Set<String> _owned = <String>{};

  /// 현재 파티 (heroId 목록, 편성 순서 보존).
  final List<String> _party = <String>[];

  HeroRoster();

  /// 게임 시작 구성: Fire Hero 1명 자동 지급 + 편성 (RPT-25).
  factory HeroRoster.initial() {
    final roster = HeroRoster();
    final starter = HeroPool.starter.heroId;
    roster.grant(starter);
    roster.assign(starter);
    return roster;
  }

  /// 저장 스냅샷([ownedIds] / [partyIds])에서 직접 복원한다.
  ///
  /// [HeroPool.byId] 로 정의가 확인되는 id 만 받아들여 잘못된 값이 전투까지
  /// 새어드는 것을 막는다. 파티는 Owned 에 포함된 영웅만 편성한다.
  factory HeroRoster.fromIds(
    Iterable<String> partyIds, {
    Iterable<String> ownedIds = const <String>[],
  }) {
    final roster = HeroRoster();
    for (final id in ownedIds) {
      if (HeroPool.byId(id) != null) roster.grant(id);
    }
    for (final id in partyIds) {
      if (roster.isOwned(id)) roster.assign(id);
    }
    return roster;
  }

  // ── 조회 ──

  bool isOwned(String heroId) => _owned.contains(heroId);

  bool isInParty(String heroId) => _party.contains(heroId);

  int get ownedTotal => _owned.length;

  int get partyTotal => _party.length;

  /// 보유 풀 id 목록 (불변 뷰, 결정론적 순서).
  List<String> get ownedIds =>
      List.unmodifiable(_owned.toList()..sort(_compareHeroId));

  /// 파티 id 목록 (편성 순서 보존, 불변 뷰).
  List<String> get partyIds => List.unmodifiable(_party);

  /// 편성된 파티 영웅 정의 목록 ([partyIds] 와 동일 순서).
  List<RuneHeroDef> get partyHeroes => [
    for (final id in _party) ?HeroPool.byId(id),
  ];

  /// 특정 속성의 보유 수 (잠금 화면 표시용).
  int ownedCount(RuneElement e) =>
      _owned.where((id) => HeroPool.byId(id)?.element == e).length;

  /// 특정 속성의 파티 편성 수 (UI 표시용).
  ///
  /// **데미지 배율은 이 값에서 나오지 않는다.** 같은 속성의 ATK 합이 그대로
  /// 데미지에 더해진다 ([BattleState.attackForElement]).
  int partyCount(RuneElement e) =>
      _party.where((id) => HeroPool.byId(id)?.element == e).length;

  /// 현재 파티의 속성별 수 (불변 뷰).
  Map<RuneElement, int> get partyCounts {
    final counts = <RuneElement, int>{};
    for (final e in RuneElement.normal) {
      final n = partyCount(e);
      if (n > 0) counts[e] = n;
    }
    return Map.unmodifiable(counts);
  }

  /// 보유(Owned) 풀의 속성별 수 (불변 뷰). 진행도 저장(RPT-316)에 사용.
  Map<RuneElement, int> get ownedCounts {
    final counts = <RuneElement, int>{};
    for (final e in RuneElement.normal) {
      final n = ownedCount(e);
      if (n > 0) counts[e] = n;
    }
    return Map.unmodifiable(counts);
  }

  // ── 변경 ──

  /// 영웅 1명 영입(Owned 풀 증가). 이미 보유했으면 false.
  bool grant(String heroId) {
    if (HeroPool.byId(heroId) == null) return false;
    return _owned.add(heroId);
  }

  /// Owned → Party 편성이 가능한가 (RPT-289).
  bool canAssign() => partyTotal < maxPartySize;

  /// Owned 풀의 영웅을 파티에 편성. 정원 초과/미보유/이미 편성 시 false.
  bool assign(String heroId) {
    if (!isOwned(heroId) || isInParty(heroId)) return false;
    if (!canAssign()) return false;
    _party.add(heroId);
    return true;
  }

  /// 파티 → Owned 풀로 해제.
  bool unassign(String heroId) => _party.remove(heroId);

  // ── 속성 집계 ──
  //
  // 데미지 계산에 쓰이는 배율은 없다. 같은 속성 영웅을 여러 명 넣으면 그 색
  // 룬의 매칭 데미지가 자동으로 커진다 — [BattleState.attackForElement] 가
  // `attackForElement` 합을 그대로 밑으로 쓰기 때문이다. 여기 남는 개수는
  // UI 표시용이다.

  /// heroId 결정론적 비교 — [HeroPool.heroes] 순서(속성 → recruitOrder)를 따른다.
  static int _compareHeroId(String a, String b) {
    final ia = HeroPool.heroes.indexWhere((h) => h.heroId == a);
    final ib = HeroPool.heroes.indexWhere((h) => h.heroId == b);
    if (ia < 0) return ib < 0 ? a.compareTo(b) : 1;
    if (ib < 0) return -1;
    return ia.compareTo(ib);
  }

  @override
  String toString() {
    final parts = RuneElement.normal
        .map((e) => '${e.label}: owned=${ownedCount(e)} party=${partyCount(e)}')
        .join(', ');
    return 'HeroRoster($parts)';
  }
}
