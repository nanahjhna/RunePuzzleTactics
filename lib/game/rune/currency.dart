/// Rune 3-재화 모델 + 거래 원장 (감사 기반 재설계)
///
/// - Game Currency  : 스테이지 승리/업그레이드 구매 (기존 gold의 역할)
/// - Play Currency  : 배틀 입장/재도전 비용 (stage entry)
/// - Hero Currency  : 영웅 영입 전용
///
///  - 3종은 **환전 불가** (서로 별도 잔액·지급처).
///  - 모든 변동은 [CurrencyTransaction] 원장에 기록하며, id 기반으로 멱등 적용해
///    중복 지급(광고 콜백 중복, 재시도 중복, 동일 일일 보상 재청구 등)을 막는다.
library;

/// 재화 종류: 게임/플레이/영웅.
enum CurrencyType { game, play, hero }

/// 거래 종류 (원장 레이블).
enum CurrencyTxType {
  /// 스테이지 승리 보상 (+Game).
  stageReward,

  /// 배틀 입장/재도전 비용 (-Play).
  stageEntry,

  /// 일일 보상 (+Play +Hero, 하루 1회).
  dailyReward,

  /// 보상형 광고 시청 (+Play 또는 +Hero, 멱등 id).
  rewardedAd,

  /// 영웅 영입 (-Hero).
  heroRecruit,

  /// 영구 업그레이드 구매 (-Game).
  upgradePurchase,

  /// 초기화 (모든 잔액 0).
  reset,
}

/// 거래 원장 1건: 재화 변동의 최소 단위.
///
/// [id]가 중복되면 [RuneProgress.applyCurrency]가 적용을 생략한다 (멱등 보장).
class CurrencyTransaction {
  const CurrencyTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.txType,
    required this.source,
    required this.createdAtMs,
  });

  /// 멱등 키. 동일 id는 두 번 적용되지 않는다 (예: 'daily_play_2026-09-23').
  final String id;

  /// 변동 대상 재화.
  final CurrencyType type;

  /// 지급(+) 또는 차감(-) 금액.
  final int amount;

  /// 거래 종류.
  final CurrencyTxType txType;

  /// 발생 지점 (예: 'battle', 'daily', 'ad', 'shop'). 표시/분석용.
  final String source;

  /// Unix ms 타임스탬프.
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'txType': txType.name,
    'source': source,
    'createdAtMs': createdAtMs,
  };

  static CurrencyTransaction fromJson(Map<String, dynamic> json) {
    return CurrencyTransaction(
      id: json['id'] as String? ?? '',
      type: CurrencyType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => CurrencyType.game,
      ),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      txType: CurrencyTxType.values.firstWhere(
        (t) => t.name == json['txType'],
        orElse: () => CurrencyTxType.stageReward,
      ),
      source: json['source'] as String? ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
