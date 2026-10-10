/// Per-battle damage records captured at the point combat HP is changed.
library;

import 'damage.dart';
import 'rune_element.dart';

enum BattleDamageSource {
  runeMatch,
  heroSkill,

  /// 독 스택 지속 피해 (매 몬스터 턴 틱).
  poisonTick,
  blackRune,
  monsterAttack,
  bossUltimate,
}

class BattleDamageRecord {
  const BattleDamageRecord({
    required this.source,
    required this.damage,
    this.element,
    this.incoming,
    this.hpBefore,
    this.hpAfter,
    this.hpMax,
  });

  final BattleDamageSource source;
  final int damage;
  final RuneElement? element;
  final IncomingDamageResult? incoming;
  final int? hpBefore;
  final int? hpAfter;
  final int? hpMax;

  bool get isIncoming =>
      source == BattleDamageSource.blackRune ||
      source == BattleDamageSource.monsterAttack ||
      source == BattleDamageSource.bossUltimate;
}

class BattleDamageStats {
  final List<BattleDamageRecord> _records = [];

  List<BattleDamageRecord> get records => List.unmodifiable(_records);

  void record(BattleDamageRecord record) => _records.add(record);

  BattleDamageSummary snapshot() => BattleDamageSummary(_records);
}

class BattleDamageSummary {
  BattleDamageSummary(Iterable<BattleDamageRecord> records)
    : records = List.unmodifiable(records);

  final List<BattleDamageRecord> records;

  int get totalDamageDealt => records
      .where((record) => !record.isIncoming)
      .fold(0, (total, record) => total + record.damage);

  int get totalDamageReceived => records
      .where((record) => record.isIncoming)
      .fold(0, (total, record) => total + record.damage);

  int countFor(BattleDamageSource source) =>
      records.where((record) => record.source == source).length;

  int damageFor(BattleDamageSource source) => records
      .where((record) => record.source == source)
      .fold(0, (total, record) => total + record.damage);

  BattleDamageRecord? get largestOutgoingHit {
    BattleDamageRecord? largest;
    for (final record in records) {
      if (record.isIncoming) continue;
      if (largest == null || record.damage > largest.damage) largest = record;
    }
    return largest;
  }

  List<BattleDamageRecord> get incomingRecords =>
      records.where((record) => record.isIncoming).toList(growable: false);
}
