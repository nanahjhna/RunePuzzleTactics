/// Rune Puzzle Tactics — 중앙 다국어 문자열 관리 (Localization)
///
/// en/ko/ja/zh-Hans/zh-Hant 5개 언어의 사용자 노출 문자열을 "동일한 키 구조"로
/// 중앙 관리한다.
///  - en keys == ko keys == ja keys == zh-Hans keys == zh-Hant keys
///    (테스트로 검증, test/l10n/app_strings_test.dart)
///  - 게임 로직의 enum/id/key/data 값은 절대 번역하지 않는다.
///  - 번역은 화면(표시 계층)에서만 적용하며, 실제 값은 [AppLocalizations]로 조회한다.
///
/// 키 목록은 UI/common/nav/title/lobby/party/shop/settings/battle/result/tutorial/
/// element/upgrade 등 영역별 접두어를 사용한다. {placeholder}는 [AppLocalizations.trp]
/// 로 치환한다.
library;

import 'app_language.dart';

/// 특정 언어의 번역 표를 감싸는 조회 객체.
///
/// 위젯에서는 `LanguageScope.of(context).strings.tr('key')` 형태로 사용한다.
/// 키가 없는 경우 빈 문자열을 표시하지 않도록 en 폴백 → key 문자열까지 폴백한다.
class AppLocalizations {
  const AppLocalizations._(this.language, this._table);

  factory AppLocalizations(AppLanguage language) =>
      AppLocalizations._(language, tableFor(language));

  final AppLanguage language;
  final Map<String, String> _table;

  /// 단순 키 조회. 누락 시 en 폴백 → key 문자열 폴백 (빈 문자열을 반환하지 않음).
  String tr(String key) => _table[key] ?? _en[key] ?? key;

  /// {placeholder} 치환 포함 조회.
  String trp(String key, [Map<String, Object> params = const {}]) {
    var text = tr(key);
    for (final entry in params.entries) {
      text = text.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return text;
  }

  /// 이 언어가 해당 키를 갖고 있는지 (검증 테스트용).
  bool containsKey(String key) => _table.containsKey(key);

  /// 이 언어 표의 원본 번역 값 (누락 시 null). 검증 테스트용.
  String? raw(String key) => _table[key];

  /// 이 언어의 전체 키 집합 (검증 테스트용).
  Set<String> get keys => _table.keys.toSet();

  /// 언어별 원본 표에 접근 (검증 테스트용).
  static const Map<String, String> enStrings = _en;
  static const Map<String, String> koStrings = _ko;
  static const Map<String, String> jaStrings = _ja;
  static const Map<String, String> zhHansStrings = _zhHans;
  static const Map<String, String> zhHantStrings = _zhHant;

  static Map<String, String> tableFor(AppLanguage lang) => switch (lang) {
    AppLanguage.en => _en,
    AppLanguage.ko => _ko,
    AppLanguage.ja => _ja,
    AppLanguage.zhHans => _zhHans,
    AppLanguage.zhHant => _zhHant,
  };

  // ─────────────────────────────────────────────────────────────
  // English (en)
  // ─────────────────────────────────────────────────────────────
  static const Map<String, String> _en = {
    // 공통
    'common_cancel': 'Cancel',
    'common_retry': 'Retry',
    'currency_game': '⚡ {n}',
    'currency_play': '🎟 {n}',
    'currency_hero': '⭐ {n}',
    'common_stage': 'STAGE {n}',

    // 제목 화면
    'title_subtitle': 'Rune Puzzle Tactics',
    'title_start': 'Start Battle',

    // 하단 내비게이션
    'nav_lobby': 'Lobby',
    'nav_party': 'Party',
    'nav_shop': 'Shop',
    'nav_settings': 'Settings',

    // 메인 허브
    'main_load_error': 'Failed to load saved data.',
    'main_reset_done': 'Progress has been reset.',
    'exit_confirm': 'Press back again to exit',

    // 로비
    'lobby_mode_title': '🧩 RUNE Mode',
    'lobby_best_clear': 'Best Clear',
    'lobby_record': 'Record',
    'lobby_record_value': '{wins}W {losses}L',
    'lobby_battle_start': 'Start Battle (STAGE {n})',
    'entry_cost_label': 'Entry Cost: 🎟 {n}',
    'entry_error_no_play': 'Not enough Play Currency. ({n} 🎟 needed)',
    'entry_short_title': 'Not Enough Play Currency',
    'entry_short_watch_ad': 'Watch Ad (+{n} 🎟)',
    'entry_short_go_shop': 'Go to Shop',
    'daily_reward_title': '🎁 Daily Reward',
    'daily_reward_desc': '🎟 +{play} · ⭐ +{hero} (once a day)',
    'daily_reward_claim': 'Claim',
    'daily_reward_claimed': 'Claimed Today',
    'ad_reward_play': '▶ Watch Ad: +{n} 🎟',
    'ad_reward_hero': '▶ Watch Ad: +{n} ⭐',
    'ad_load_failed': 'Could not load the ad. Please try again later.',
    'ad_play_owned': 'You already have Play tickets.',
    'ad_hero_daily_done': 'Hero ad reward is available again tomorrow.',
    'ad_reward_granted': '+{n} reward received!',
    'lobby_view_upgrades': 'View Permanent Upgrades',
    'party_summary': 'Current Party',
    'hero_owned': 'Owned {n}',

    // 속성 인원수 표기 (배율은 붙지 않는다 — 공격력 합이 곧 데미지 밑).
    'party_count_unit': '{n}',

    // 파티
    'party_title': 'Party Management',
    'party_counter': 'Party {total} / {max}',
    'party_desc':
        'Matching a rune deals damage equal to the summed attack of the living '
        'heroes of that same element, multiplied by combo and the stage affinity. '
        'So heroes of the same element stack up on their own colour.',
    'party_recruit_hint':
        '💡 You can recruit heroes with Hero Currency (⭐) in the Shop tab.',
    'party_unassign_tooltip': 'Remove from Party',
    'party_assign_tooltip': 'Add to Party',
    'party_assign_confirm_title': 'Join Hero',
    'party_assign_confirm_message':
        'Would you like to add {hero} to the party?',
    'party_assign_yes': 'Yes',
    'party_assign_no': 'No',
    'party_in_party': 'Party',
    'party_tab_all': 'Party',
    'party_empty_hint': 'No heroes owned yet. Recruit in the Shop tab.',
    'party_slot_add_tooltip': 'Tap to add a hero',
    'party_slots_full': 'Party is full (5/5)',
    'party_synergy_none': 'No heroes in the party',
    'party_picker_title': 'Select a Hero',
    'party_picker_counter': 'Party {total} / {max}',
    'party_picker_assigned': 'IN PARTY',
    'party_picker_empty': 'No heroes available. Recruit in the Shop tab.',
    'party_picker_hint': 'Tap a hero to join them to your party.',
    'party_unassign_confirm_title': 'Remove from Party',
    'party_unassign_confirm_message': 'Remove {hero} from the party?',
    'hero_name_fire_a': 'Ember',
    'hero_name_grass_a': 'Liana',
    'hero_name_water_a': 'Maris',
    'hero_name_light_a': 'Lumia',
    'hero_name_poison_a': 'Nyx',

    // 영웅 상세 팝업 / 영웅도감
    'hero_detail_desc_label': 'Description',
    'hero_detail_skill_label': 'Hero Skill',
    'hero_skill_none': 'This hero has no skill.',
    // 영웅별 스킬 상세 — **요소별 스킬**(속성당 1종, 속성당 영웅 1명).
    'hero_skill_fire_a':
        'Once per stage: pick a rune — every rune of that colour on the board becomes a Fire Rune.',
    'hero_skill_water_a':
        'Once per stage: deals 10 damage for every Water Rune on the board.',
    'hero_skill_grass_a':
        'Once per stage: restores 10 HP for every Grass Rune on the board.',
    'hero_skill_light_a':
        'Once per stage: pick any rune — the 3x3 area around it explodes and the rest falls in.',
    'hero_skill_poison_a':
        'Once per stage: burns every Poison Rune on the board, dealing 10 damage for each one removed. The rest falls in.',
    'hero_state_not_owned': 'Not Owned',
    'hero_detail_starter': 'Starter (Free)',
    'hero_detail_stats_label': 'Base Stats',
    'stat_hp': 'HP',
    'stat_atk': 'ATK',
    'stat_def': 'DEF',
    'hero_detail_open': 'Details',
    'hero_level_label': 'Level',
    'hero_level_bonus': 'Level Bonus',
    'hero_level_max': 'MAX',
    'hero_exp_progress': '{exp} / {next} EXP',
    'result_level_up_title': '⬆ LEVEL UP',
    'result_level_up_line': 'Lv.{from} → Lv.{to}',
    'result_hero_exp_title': 'Hero Growth',
    'result_hero_exp_gain': '+{n} EXP',

    // 등급 설명은 접근성/부가 정보용이며 UI 표기는 별 개수로 처리한다.
    'rarity_r': 'Common',
    'rarity_sr': 'Rare',
    'rarity_ssr': 'Epic',
    'rarity_ur': 'Legendary',

    // 영웅 랜덤 영입(뽑기)
    'gacha_header': 'Recruit Heroes (Hero Currency ⭐)',
    'gacha_single': 'Recruit ×1',
    'gacha_ten': 'Recruit ×10',
    'gacha_cost': '⭐{n}',
    'gacha_rates_header': 'Rates',
    'gacha_rates_note':
        'Higher rarities unlock with stage progress. '
        'Duplicates are absorbed by your highest-grade hero.',
    'gacha_codex_progress': 'Heroes owned {owned} / {total}',
    'gacha_badge_new': 'NEW',
    'gacha_badge_promote': 'UPGRADED',
    'gacha_badge_levelup': 'Lv UP',
    'gacha_badge_max': 'MAX GRADE',
    'gacha_promote_to': '{from} → {to}',
    'gacha_confirm': 'Confirm',
    'gacha_error_hero': 'Not enough Hero Currency. ({n} ⭐ needed)',
    'gacha_error_hero_count':
        'Not enough Hero Currency. ({n} ⭐ needed for {count})',
    'gacha_empty_pool': 'No recruitable heroes yet.',
    'hero_codex_title': '📖 Hero Codex',
    'hero_codex_desc':
        'All 5 heroes. Tap any hero to see their description and skill.',
    'hero_desc_fire_a':
        'The very first fire hero. She handles a burning rune flow as naturally '
        'as breathing, which makes her the finest hand at fire orbs.',
    'hero_desc_grass_a':
        'A healer who reads the party\u2019s stamina before anyone speaks. Her grass '
        'flow quietly mends what the fire heroes burn away.',
    'hero_desc_water_a':
        'A calm surface with a bottomless current. She is the one who washes the '
        'black residue off the board.',
    'hero_desc_light_a':
        'A bright soul that has yet to learn what her light is for. Still standing '
        'at the front of the party, holding the line.',
    'hero_desc_poison_a':
        'She handles poison with her bare hands, yet the party\u2019s health barely '
        'shudders. A first step into a hard school.',

    // 상점
    'shop_title': '🛒 Shop',
    'shop_upgrades_header': 'Party Stat Books & Upgrades',
    'shop_owned_badge': 'Owned',
    'shop_locked_unlock': 'Unlocks at Stage {n}',
    'shop_error_max_level': 'Already at max level.',
    'shop_error_game': 'Not enough Game Currency. ({n} ⚡ needed)',
    'shop_effect': 'Effect: {label}',
    'shop_max_level': 'Max Level',
    'shop_buy': 'Buy ({n} ⚡)',
    'shop_lv': 'Lv. {level} / {max}',
    'book_level': 'Lv. {level}',
    'book_purchase_success': 'Book upgraded. Party stats increased!',
    'book_name_hp': 'Book of Life',
    'book_name_atk': 'Tome of Valor',
    'book_name_def': 'Book of Protection',
    'book_name_affinity_bonus': 'Book of Rupture',
    'book_name_affinity_resistance': 'Book of Warding',
    'book_stat_hp': 'Party HP',
    'book_stat_atk': 'Party ATK',
    'book_stat_def': 'Party DEF',

    // 업그레이드
    'upgrade_name_partyAttack': 'Party Attack',
    'upgrade_name_partyMaxHp': 'Party Max HP',
    'upgrade_name_gameGain': 'Game Currency Gain',
    'upgrade_desc_partyAttack':
        'Increases the Party Base Attack by +10 per level.',
    'upgrade_desc_partyMaxHp': 'Increases the party max HP by +10 per level.',
    'upgrade_desc_gameGain':
        'Increases Game Currency earned on victory by +10% per level.',
    'upgrade_effect_partyAttack': 'Attack',
    'upgrade_effect_partyMaxHp': 'Max HP',
    'upgrade_effect_gameGain': 'Game Currency Gain',

    // 설정
    'settings_title': '⚙ Settings',
    'settings_section_tutorial': 'Tutorial',
    'settings_replay_tutorial': 'Replay Tutorial',
    'settings_audio': 'Audio',
    'settings_music': 'Background Music',
    'settings_sound_effects': 'Sound Effects',
    'settings_section_data': 'Data',
    'settings_reset_progress': 'Reset Progress',
    'settings_language': 'Language',
    'settings_language_select': 'Select Language',
    'settings_language_current': 'Current Language: {name}',
    'settings_reset_dialog_title': 'Reset Progress',
    'settings_reset_dialog_msg':
        'All currencies / clears / upgrades / party will be deleted.\nContinue?',
    'settings_reset_confirm': 'Reset',
    'settings_footer':
        'Rune Puzzle Tactics v0.8\nLocal save (SQLite) · '
        'Firebase Analytics ready',

    // 앱 정보 (요구사항 10)
    'common_close': 'Close',
    'settings_section_about': 'About',
    'settings_credits': 'Credits',
    'settings_rate_app': 'Rate the App',
    'settings_other_apps': 'Browse Other Apps',
    'settings_coming_soon': 'Coming soon',
    'credits_title': 'Credits',
    'credits_version': 'Version {version}',
    'credits_role_dev': 'Development & Design — Rune Puzzle Tactics Team',
    'credits_role_art': 'Art — pixel & card artwork pack',
    'credits_role_sound': 'Sound — BFXR sound pack',
    'credits_role_thanks': 'Thanks for playing!',

    // 마지막 플레이 스테이지 (요구사항 1)
    'lobby_last_played': 'Last played',
    'lobby_last_result_win': 'Cleared',
    'lobby_last_result_lose': 'Defeated — try again',

    // 파티 `+` 비활성 사유 (요구사항 5)
    'party_slots_nothing_to_add': 'All owned heroes are already in the party',

    // 영웅도감 그리드 (요구사항 6)
    'codex_owned_count': 'Owned {owned} / {total}',

    // 영웅 영입 천상 (요구사항 9)
    'gacha_pity_progress': 'New hero guaranteed in {n} more single pull(s)',
    'gacha_pity_counter': '{count} / {max} in a row',
    'gacha_pity_ready': 'PITY READY — next single pull is a NEW hero',
    'gacha_pity_note': 'Dupe pulls stack up. 10-pulls are not affected.',
    'gacha_skip': 'Skip',
    'gacha_congrats_new': 'NEW HERO!',
    'gacha_ten_no_new': 'No new hero this time',

    // 언어 선택 다이얼로그
    'lang_dialog_title': 'Select Language',
    'lang_en': 'English',
    'lang_ko': '한국어',
    'lang_ja': '日本語',
    'lang_zh_hans': '简体中文',
    'lang_zh_hant': '繁體中文',

    // 배틀
    'battle_leave_tooltip': 'Leave',
    'battle_type_boss': 'Boss',
    'battle_boss_ultimate_warning': '⚠ Ultimate next attack!',
    'battle_type_elite': 'Elite',
    'battle_type_normal': 'Normal',
    'battle_pause_tooltip': 'Pause',
    'turn_monster': '⚠ Monster Turn',
    'turn_victory': '🏆 Victory',
    'turn_defeat': '💀 Defeat',
    'turn_retreat': 'Leave',
    'turn_player': '▶ Player Turn',
    'hp_party': '🛡 Party',
    'hp_monster': '👹 Monster',
    'combo': 'COMBO x{n}',
    'battle_paused': 'Paused',
    'battle_resume': 'Resume',
    'battle_restart': 'Restart',
    'battle_go_lobby': 'Go to Lobby',
    'battle_ready_go': 'Ready... GO!',

    // 스테이지 준비 (진입 전 확인, 요구사항 6.1 / 사양 1-2)
    'stage_prep_title': 'Stage Prep',
    'stage_prep_monster_count': 'Monsters: {n}',
    'stage_prep_party': 'MY ENTRY PARTY',
    'stage_prep_confirm': 'Start Battle',
    'stage_prep_play_held': '/ Held {n}',
    'stage_prep_info_body':
        'Monsters have no element, but each stage has a weakness (x1.5) and a '
        'resist element (x0.5). A rune match deals damage equal to the summed '
        'attack of your living heroes of that element, times combo, times '
        'affinity.\n'
        'Tap an empty slot (+) to add a hero. Tap a hero portrait to use its '
        'skill. Each hero can use a skill once per stage, and only one skill can '
        'be used per player turn.',
    'incoming_damage_formula':
        'ATK {atk} x 100 / (100 + DEF {def}) = -{damage}; '
        'HP {hpBefore}->{hpAfter}/{hpMax}',

    // 몬스터 상성 (몬스터는 무속성 — 약점/열세는 현재 등장 몬스터 기준)
    'battle_monster_weak': 'WEAK',
    'battle_monster_resist': 'RESIST',
    // 파도 전투 — 몬스터가 순서대로 등장한다 (현재 n / 총 N).
    'battle_monster_wave': 'Monster {i}/{n}',

    // 파도 처치 보상 — 몬스터를 처치하면 파티 HP 회복 + 스킬 충전(1명)
    'wave_reward_title': 'Monster Slain!',
    'wave_reward_heal': 'Party HP +{n} recovered',
    'wave_reward_skill': 'Recharge a skill (1 hero)',
    'wave_reward_skip': 'Skip',

    // 로비 스테이지 카드 / 파티 요약 (사양 1-1)
    'lobby_stage_progress': 'Unlocked up to {cleared}',
    'lobby_max_stage_banner': 'Final stage reached! You can replay it.',
    'lobby_current_party': 'CURRENT PARTY',
    'lobby_party_stats': 'HERO STATS',
    'lobby_party_defense': 'Party DEF',
    'lobby_upgrade_levels': 'PERMANENT UPGRADES',

    // 영웅 스킬
    'battle_skill_used': 'USED',
    // 표적 지정 스킬(Fire/Light)에서 보드의 대상 칸을 고르는 중.
    'battle_skill_aiming': 'AIM',
    // 쓰러진 영웅(초상화 하단 HP 0 → ✕ 오버레이)
    'battle_hero_down': 'DOWN',
    // 매치는 했는데 그 속성 영웅이 파티에 없어 데미지가 0이었을 때 몬스터 중앙 경고.
    'battle_no_element_hero': '영웅이 없어 데미지가 들어가지 않았습니다',
    // 로비 스테이지 카드 — 이전 스테이지 표시.
    'lobby_previous_stage': '이전 스테이지',
    'shop_per_hero': 'each',
    // 영웅별 HUD 라벨 — **요소별 스킬**이라 요소마다 하나씩이다.
    'battle_hero_skill_fire_a': 'Inferno',
    'battle_hero_skill_water_a': 'Tide Strike',
    'battle_hero_skill_grass_a': 'Bloom',
    'battle_hero_skill_light_a': 'Blast',
    'battle_hero_skill_poison_a': 'Venom Burst',
    // 스킬이 없는 영웅의 전투 캡션 (상세 다이얼로그의 문장 키와 구분).
    'battle_skill_none': 'NO SKILL',
    // 스킬 설명 팝업 하단 — 사용 횟수 안내.
    'battle_skill_once': 'Once per stage',

    // 결과
    'result_victory': '🎉 Victory!',
    'result_defeat': '💀 Defeat',
    'result_clear': 'Stage {n} Cleared!',
    'result_defeated': 'Defeated at Stage {n}.',
    'result_game_win': 'Game Currency Earned',
    'result_game_loss': 'Game Currency (no reward on defeat)',
    'result_attack': '⚔ Attack {n}',
    'result_damage_analysis': 'Battle Damage Analysis',
    'result_damage_dealt': 'Damage dealt',
    'result_damage_received': 'Damage received',
    'result_largest_hit': 'Largest single hit',
    'result_damage_sources': 'By damage source (hits × total)',
    'result_incoming_breakdowns': 'Incoming damage calculations',
    'result_party_stat_breakdown': 'Final stats by hero',
    'result_stat_breakdown_legend':
        'Each hero\u2019s attack adds to their element\u2019s rune damage \u00b7 DEF reduces the monster counterattack',
    'damage_source_runeMatch': 'Rune matches',
    'damage_source_heroSkill': 'Hero skills',
    'damage_source_poisonTick': 'Poison stacks',
    'damage_source_blackRune': 'Black rune hits',
    'damage_source_monsterAttack': 'Monster attacks',
    'damage_source_bossUltimate': 'Boss ultimate',
    'damage_total': 'MATCH TOTAL',
    'damage_overflow': '+{n} hits · {d}',
    'result_btn_next': 'Next Stage ▶',
    'result_btn_retry': 'Retry (Play {n})',
    'result_btn_shop': 'Go to Shop (grow and retry)',
    'result_btn_lobby': 'Go to Lobby',

    // 튜토리얼
    'tutorial_title': '🎓 Tutorial',
    'tutorial_skip': 'Skip',
    'tutorial_help': 'Help',
    'tutorial_step': 'STEP {current} / {total}',
    'tutorial_step_tag': 'STEP {current} · {id}',
    'tutorial_hint': '💡 Hint: swipe {from} ⇄ {to}',
    'tutorial_tile_label': '(col {col}, row {row})',
    'tutorial_skill_tap': 'Tap the hero portrait to use its skill',
    // Fire/Light 은 표적 지정 스킬 — 포트레이트 한 번으론 끝나지 않는다.
    'tutorial_skill_tap_target':
        'Tap the portrait, then tap a rune on the board to aim',
    'tutorial_skip_dialog_title': 'Skip Tutorial',
    'tutorial_skip_dialog_msg':
        'You might miss parts of the tutorial.\nSkip anyway?',
    'tutorial_continue': 'Continue',
    'tutorial_title_match': 'Match 3 of the same rune',
    'tutorial_msg_match':
        'There are 🔥 Fire runes lined up vertically on the board.\n'
        'Swipe a rune to swap it with a neighbor to clear 3 and attack the '
        'monster!',
    'tutorial_title_affinity': 'Aim for the monster weakness',
    'tutorial_msg_affinity':
        'Damage = the summed attack of your living heroes of that element '
        '× combo × affinity.\n'
        'This monster is weak to 🔥 Fire, so it takes ×1.5. Clear 3 Fire runes.',
    'tutorial_title_combo': 'Cascades make combos!',
    'tutorial_msg_combo':
        'After a match, runes fall and can group again into a COMBO!\n'
        'Each combo adds +20% damage. Leave the GGG at the top and swipe.',
    'tutorial_title_monster': 'The monster attacks when your turn ends',
    'tutorial_msg_monster':
        'When your turn ends after a swipe, the monster attacks.\n'
        'Watch your party HP (🛡 Party) decrease.',
    'tutorial_title_black-danger': '🖤 Black runes are dangerous',
    'tutorial_msg_black-danger':
        'Matching 3 or more Black runes damages your party!\n'
        'There are 3 Black runes adjacent on the board. Swiping will hurt '
        'you… be careful.',
    'tutorial_title_black-4-line': 'Black 4 damages + line purge!',
    'tutorial_msg_black-4-line':
        'Matching 4 Black runes damages your party AND purges every other '
        'Black in the same line!\n'
        'The board has 4 Black in a row plus 1 more to purge. Swipe to see '
        'the line purge.',
    'tutorial_title_black-purge': 'Line up 5 Black runes to purge!',
    'tutorial_msg_black-purge':
        'Making a line of 5 Black runes purges all Black on the board '
        'without damage.\n'
        'There are already 5 Black runes at the bottom. Don\'t touch them, '
        'swipe other runes.',
    'tutorial_title_skill': 'Use a hero skill',
    'tutorial_msg_skill':
        'Tap a hero portrait to activate that hero\'s skill.\n'
        'Each hero can use a skill once per stage. You can use only one skill '
        'per player turn, and the monster attacks after a skill is used.',
    'tutorial_title_boss': 'Final! Defeat the boss',
    'tutorial_msg_boss':
        'Match 🔥 Fire 3 times to defeat the boss and finish the tutorial!\n'
        'Winning the battle grants a gold reward and advances to the next '
        'stage.',

    // 첫 패배 동료 영입 가이드
    'guide_name': 'Guide',
    'guide_first_defeat_msg':
        'You fell because you were short on companions.\n'
        'Here, I\'ll help you — use this to recruit one.',
    'guide_first_defeat_cta': 'Recruit a companion',
    'guide_first_defeat_cancel': 'Maybe later',
    'guide_shop_banner':
        'Tap the single pull below to recruit a new companion!',
    'guide_pull_done_msg':
        'Now you have a companion to fight alongside you.\n'
        'Shall we challenge the stage again?',
    'guide_pull_done_cta': 'Go to lobby & retry',

    // 요소명 (RuneElement.name → 번역)
    'element_fire': 'Fire',
    'element_grass': 'Grass',
    'element_water': 'Water',
    'element_light': 'Lightning',
    'element_poison': 'Poison',
    'element_black': 'Black',
  };

  // ─────────────────────────────────────────────────────────────
  // 한국어 (ko)
  // ─────────────────────────────────────────────────────────────
  static const Map<String, String> _ko = {
    // 공통
    'common_cancel': '취소',
    'common_retry': '다시 시도',
    'currency_game': '⚡ {n}',
    'currency_play': '🎟 {n}',
    'currency_hero': '⭐ {n}',
    'common_stage': 'STAGE {n}',

    // 제목 화면
    'title_subtitle': '룬 퍼즐 타격 전술',
    'title_start': '전투 시작',

    // 하단 내비게이션
    'nav_lobby': '로비',
    'nav_party': '파티',
    'nav_shop': '상점',
    'nav_settings': '설정',

    // 메인 허브
    'main_load_error': '저장 데이터를 불러오지 못했습니다.',
    'main_reset_done': '진행도가 초기화되었습니다.',
    'exit_confirm': '뒤로가기를 한 번 더 누르면 종료됩니다.',

    // 로비
    'lobby_mode_title': '🧩 RUNE 모드',
    'lobby_best_clear': '최고 클리어',
    'lobby_record': '전적',
    'lobby_record_value': '{wins}승 {losses}패',
    'lobby_battle_start': '전투 시작 (STAGE {n})',
    'entry_cost_label': '입장 비용: 🎟 {n}',
    'entry_error_no_play': '플레이 재화가 부족합니다. (필요 {n} 🎟)',
    'entry_short_title': '플레이 재화 부족',
    'entry_short_watch_ad': '광고 시청 (+{n} 🎟)',
    'entry_short_go_shop': '상점으로 이동',
    'daily_reward_title': '🎁 일일 보상',
    'daily_reward_desc': '🎟 +{play} · ⭐ +{hero} (하루 1회)',
    'daily_reward_claim': '수령',
    'daily_reward_claimed': '오늘 수령 완료',
    'ad_reward_play': '▶ 광고 시청: +{n} 🎟',
    'ad_reward_hero': '▶ 광고 시청: +{n} ⭐',
    'ad_load_failed': '광고를 불러올 수 없습니다. 잠시 후 다시 시도해 주세요.',
    'ad_play_owned': 'Play 티켓을 이미 보유하고 있습니다.',
    'ad_hero_daily_done': '영웅 광고 보상은 내일 다시 받을 수 있습니다.',
    'ad_reward_granted': '+{n} 보상을 받았습니다!',
    'lobby_view_upgrades': '영구 업그레이드 보기',
    'party_summary': '현재 파티',
    'hero_owned': '보유 {n}',

    // 속성 인원수 표기 (배율은 붙지 않는다 — 공격력 합이 곧 데미지 밑).
    'party_count_unit': '{n}명',

    // 파티
    'party_title': '👥 파티 관리',
    'party_counter': '파티 {total} / {max}',
    'party_desc':
        '룬 매칭 데미지는 "그 색 살아있는 영웅의 공격력 합" × 콤보 × 상성입니다. 같은 속성 영웅을 여러 명 넣으면 그 색 데미지가 자동으로 커집니다.',
    'party_recruit_hint': '💡 영웅 영입은 상점 탭에서 영웅 재화(⭐)로 진행할 수 있습니다.',
    'party_unassign_tooltip': '파티에서 해제',
    'party_assign_tooltip': '파티에 편성',
    'party_assign_confirm_title': '영웅 합류',
    'party_assign_confirm_message': '{hero}을(를) 파티에 합류시키겠습니까?',
    'party_assign_yes': '예',
    'party_assign_no': '아니오',
    'party_in_party': '편성',
    'party_tab_all': '파티',
    'party_empty_hint': '보유한 영웅이 없습니다. 상점 탭에서 영웅을 영입해 주세요.',
    'party_slot_add_tooltip': '눌러서 영웅 편성',
    'party_slots_full': '파티가 가득 찼습니다 (5/5)',
    'party_synergy_none': '파티에 영웅이 없습니다',
    'party_picker_title': '영웅 선택',
    'party_picker_counter': '파티 {total} / {max}',
    'party_picker_assigned': '편성중',
    'party_picker_empty': '편성할 수 있는 영웅이 없습니다. 상점에서 영입해 주세요.',
    'party_picker_hint': '영웅을 누르면 파티에 합류시킵니다.',
    'party_unassign_confirm_title': '파티에서 제외',
    'party_unassign_confirm_message': '{hero}을(를) 파티에서 제외할까요?',
    'hero_name_fire_a': '엠버',
    'hero_name_grass_a': '리아나',
    'hero_name_water_a': '마리스',
    'hero_name_light_a': '루미아',
    'hero_name_poison_a': '닉스',

    // 영웅 상세 팝업 / 영웅도감
    'hero_detail_desc_label': '설명',
    'hero_detail_skill_label': '영웅 스킬',
    'hero_skill_none': '이 영웅에는 스킬이 없습니다.',
    // 영웅별 스킬 상세 — **요소별 스킬**(속성당 1종, 속성당 영웅 1명).
    'hero_skill_fire_a': '스테이지당 1회: 룬 하나를 고르면 그 색의 룬이 보드 전부 불 룬으로 바뀝니다.',
    'hero_skill_water_a': '스테이지당 1회: 보드의 물 룬 개수만큼 10씩 직접 피해를 가합니다.',
    'hero_skill_grass_a': '스테이지당 1회: 보드의 초록 룬 개수만큼 10씩 파티를 회복시킵니다.',
    'hero_skill_light_a': '스테이지당 1회: 아무 룬이나 고르면 그 칸의 3×3 영역이 폭발하고 나머지가 떨어집니다.',
    'hero_skill_poison_a':
        '스테이지당 1회: 보드의 독 룬을 전부 태워 없애고, 없앤 개수만큼 10씩 즉시 피해를 가합니다. 나머지 룬이 떨어집니다.',
    'hero_state_not_owned': '미보유',
    'hero_detail_starter': '스타터(무료)',
    'hero_detail_stats_label': '기본 스탯',
    'stat_hp': 'HP',
    'stat_atk': 'ATK',
    'stat_def': 'DEF',
    'hero_detail_open': '상세',
    'hero_level_label': '레벨',
    'hero_level_bonus': '레벨 보너스',
    'hero_level_max': 'MAX',
    'hero_exp_progress': '{exp} / {next} EXP',
    'result_level_up_title': '⬆ 레벨 업',
    'result_level_up_line': 'Lv.{from} → Lv.{to}',
    'result_hero_exp_title': '영웅 성장',
    'result_hero_exp_gain': '+{n} EXP',

    // 등급 설명은 접근성/부가 정보용이며 UI 표기는 별 개수로 처리한다.
    'rarity_r': '보통',
    'rarity_sr': '희귀',
    'rarity_ssr': '영웅',
    'rarity_ur': '전설',

    // 영웅 랜덤 영입(뽑기)
    'gacha_header': '영웅 영입 (영웅 재화 ⭐)',
    'gacha_single': '1연 뽑기',
    'gacha_ten': '10연 뽑기',
    'gacha_cost': '⭐{n}',
    'gacha_rates_header': '등급 확률',
    'gacha_rates_note':
        '높은 등급은 스테이지 진행에 따라 해금됩니다. '
        '중복은 보유 영웅 중 최고 등급 영웅이 흡수합니다.',
    'gacha_codex_progress': '보유 영웅 {owned} / {total}',
    'gacha_badge_new': '신규',
    'gacha_badge_promote': '등급 상승',
    'gacha_badge_levelup': '레벨 업',
    'gacha_badge_max': '최고 등급',
    'gacha_promote_to': '{from} → {to}',
    'gacha_confirm': '확인',
    'gacha_error_hero': '영웅 재화가 부족합니다. (필요 {n} ⭐)',
    'gacha_error_hero_count': '영웅 재화가 부족합니다. ({count}연에 {n} ⭐ 필요)',
    'gacha_empty_pool': '아직 영입할 수 있는 영웅이 없습니다.',
    'hero_codex_title': '📖 영웅도감',
    'hero_codex_desc': '전체 5명의 영웅입니다. 영웅을 누르면 설명과 스킬을 볼 수 있습니다.',
    'hero_desc_fire_a': '최초의 불 영웅. 타오르는 룬 흐름을 눈치깐 다가가며, 폭발 오브를 다루는 데 가장 능숙합니다.',
    'hero_desc_grass_a': '아무도 말하기 전에 파티의 체력을 읽어내는 치유자. 불이 태운 흔적은 풀로 조용히 메웁니다.',
    'hero_desc_water_a': '겉은 잔잔하고 밑바닥은 끝이 없는 물길. 판에서 검은 잔재를 씻어내는 일은 그녀의 몫입니다.',
    'hero_desc_light_a':
        '아직 자신의 빛이 무엇을 위한 것인지 배우지 못한 밝은 영혼. 그래도 파티의 맨 앞을 지키고 있습니다.',
    'hero_desc_poison_a': '독을 맨손으로 다루면서도 파티의 체력은 크게 흔들리지 않습니다. 험난한 길의 첫걸음입니다.',

    // 상점
    'shop_title': '🛒 상점',
    'shop_upgrades_header': '파티 스탯 마도서 및 강화',
    'shop_owned_badge': '보유',
    'shop_locked_unlock': '{n}스테이지에서 해금',
    'shop_error_max_level': '이미 최대 레벨입니다.',
    'shop_error_game': '게임 재화가 부족합니다. (필요 {n} ⚡)',
    'shop_effect': '효과: {label}',
    'shop_max_level': '최대 레벨',
    'shop_buy': '구매 {n}⚡',
    'shop_lv': 'Lv. {level} / {max}',
    'book_level': 'Lv. {level}',
    'book_purchase_success': '마도서 강화 완료! 파티 스탯이 상승했습니다.',
    'book_name_hp': '생명의 서',
    'book_name_atk': '투지의 서',
    'book_name_def': '수호의 서',
    'book_name_affinity_bonus': '파쇄의 서',
    'book_name_affinity_resistance': '결계의 서',
    'book_stat_hp': '파티 HP',
    'book_stat_atk': '파티 ATK',
    'book_stat_def': '파티 DEF',

    // 업그레이드
    'upgrade_name_partyAttack': '파티 공격력',
    'upgrade_name_partyMaxHp': '파티 최대 체력',
    'upgrade_name_gameGain': 'Game Currency 획득',
    'upgrade_desc_partyAttack': '전투 기본 공격력(Party Base Attack)이 레벨당 +10 증가합니다.',
    'upgrade_desc_partyMaxHp': '파티 최대 HP가 레벨당 +10 증가합니다.',
    'upgrade_desc_gameGain': '승리 시 획득 Game Currency가 레벨당 +10% 증가합니다.',
    'upgrade_effect_partyAttack': '공격력',
    'upgrade_effect_partyMaxHp': '최대 체력',
    'upgrade_effect_gameGain': 'Game Currency 획득',

    // 설정
    'settings_title': '⚙ 설정',
    'settings_section_tutorial': '튜토리얼',
    'settings_replay_tutorial': '튜토리얼 다시보기',
    'settings_audio': '오디오',
    'settings_music': '배경 음악',
    'settings_sound_effects': '효과음',
    'settings_section_data': '데이터',
    'settings_reset_progress': '진행도 초기화',
    'settings_language': '언어',
    'settings_language_select': '언어 선택',
    'settings_language_current': '현재 언어: {name}',
    'settings_reset_dialog_title': '진행도 초기화',
    'settings_reset_dialog_msg': '모든 재화/클리어/업그레이드/파티가 삭제됩니다.\n계속할까요?',
    'settings_reset_confirm': '초기화',
    'settings_footer':
        'Rune Puzzle Tactics v0.8\n로컬 저장(SQLite) · Firebase Analytics 연동 준비',

    // 앱 정보 (요구사항 10)
    'common_close': '닫기',
    'settings_section_about': '앱 정보',
    'settings_credits': '크레딧',
    'settings_rate_app': '별점 매기기',
    'settings_other_apps': '다른 앱 둘러보기',
    'settings_coming_soon': '출시 준비 중',
    'credits_title': '크레딧',
    'credits_version': '버전 {version}',
    'credits_role_dev': '개발 & 디자인 — Rune Puzzle Tactics 팀',
    'credits_role_art': '아트 — 픽셀 & 카드 이미지 팩',
    'credits_role_sound': '사운드 — BFXR 사운드 팩',
    'credits_role_thanks': '플레이해 주셔서 감사합니다!',

    // 마지막 플레이 스테이지 (요구사항 1)
    'lobby_last_played': '마지막 플레이',
    'lobby_last_result_win': '클리어 성공',
    'lobby_last_result_lose': '패배 — 다시 도전',
    // 파티 `+` 비활성 사유 (요구사항 5)
    'party_slots_nothing_to_add': '보유 영웅을 모두 편성했습니다',

    // 영웅도감 그리드 (요구사항 6)
    'codex_owned_count': '보유 {owned} / {total}',

    // 영웅 영입 천상 (요구사항 9)
    'gacha_pity_progress': '신규 확정까지 {n}연',
    'gacha_pity_counter': '연속 중복 {count} / {max}',
    'gacha_pity_ready': '천상 발동! 다음 1연은 신규 확정',
    'gacha_pity_note': '중복이 쌓일수록 올라갑니다. 10연에는 적용되지 않습니다.',
    'gacha_skip': '건너뛰기',
    'gacha_congrats_new': '신규 영웅 등장!',
    'gacha_ten_no_new': '이번엔 신규 영웅이 없습니다',

    // 언어 선택 다이얼로그
    'lang_dialog_title': '언어 선택',
    'lang_en': 'English',
    'lang_ko': '한국어',
    'lang_ja': '日本語',
    'lang_zh_hans': '简体中文',
    'lang_zh_hant': '繁體中文',

    // 배틀
    'battle_leave_tooltip': '이탈',
    'battle_type_boss': '보스',
    'battle_boss_ultimate_warning': '⚠ 다음 공격은 궁극기!',
    'battle_type_elite': '엘리트',
    'battle_type_normal': '일반',
    'battle_pause_tooltip': '일시정지',
    'turn_monster': '⚠ 몬스터 턴 (MONSTER TURN)',
    'turn_victory': '🏆 승리',
    'turn_defeat': '💀 패배',
    'turn_retreat': '이탈',
    'turn_player': '▶ 플레이어 턴 (PLAYER TURN)',
    'hp_party': '🛡 파티',
    'hp_monster': '👹 몬스터',
    'combo': 'COMBO x{n}',
    'battle_paused': '일시정지',
    'battle_resume': '재개',
    'battle_restart': '다시하기',
    'battle_go_lobby': '로비로',
    'battle_ready_go': 'Ready... GO!',

    // 스테이지 준비 (진입 전 확인, 요구사항 6.1)
    'stage_prep_title': '스테이지 준비',
    'stage_prep_monster_count': '몬스터 {n}마리',
    'stage_prep_party': '출전 파티',
    'stage_prep_confirm': '전투 출격',
    'stage_prep_play_held': '/ 보유 {n}',
    'stage_prep_info_body':
        '몬스터는 무속성이지만 스테이지마다 약점(×1.5) 속성과 열세(×0.5) 속성이 '
        '있습니다. 룬 매칭 데미지는 "그 색 살아있는 영웅의 공격력 합" × 콤보 × '
        '상성입니다.\n'
        '빈 슬롯(+)을 눌러 영웅을 편성할 수 있습니다. 영웅 초상화를 눌러 스킬을 '
        '사용합니다. 각 영웅은 스테이지당 1회, 플레이어 턴마다 파티 전체에서 '
        '1회만 사용할 수 있습니다.',
    'incoming_damage_formula':
        'ATK {atk} × 100 / (100 + DEF {def}) = -{damage}; '
        'HP {hpBefore}→{hpAfter}/{hpMax}',

    // 몬스터 상성 (몬스터는 무속성 — 약점/열세는 현재 등장 몬스터 기준)
    'battle_monster_weak': '약점',
    'battle_monster_resist': '열세',
    // 파도 전투 — 몬스터가 순서대로 등장한다 (현재 n / 총 N).
    'battle_monster_wave': '몬스터 {i}/{n}',

    // 파도 처치 보상 — 몬스터를 처치하면 파티 HP 회복 + 스킬 충전(1명)
    'wave_reward_title': '몬스터 처치!',
    'wave_reward_heal': '파티 HP +{n} 회복',
    'wave_reward_skill': '스킬 충전 (1명)',
    'wave_reward_skip': '건너뛰기',

    // 로비 스테이지 카드 / 파티 요약 (사양 1-1)
    'lobby_stage_progress': '최대 진입 {cleared}',
    'lobby_max_stage_banner': '최종 스테이지 도달! 재도전할 수 있습니다.',
    'lobby_current_party': '출전 파티',
    'lobby_party_stats': '영웅 스탯',
    'lobby_party_defense': '파티 DEF',
    'lobby_upgrade_levels': '영구 업그레이드',

    // 영웅 스킬
    'battle_skill_used': '사용 완료',
    // 표적 지정 스킬(Fire/Light)에서 보드의 대상 칸을 고르는 중.
    'battle_skill_aiming': '조준',
    // 쓰러진 영웅(초상화 하단 HP 0 → ✕ 오버레이)
    'battle_hero_down': '쓰러짐',
    // 매치는 했는데 그 속성 영웅이 파티에 없어 데미지가 0이었을 때 몬스터 중앙 경고.
    'battle_no_element_hero': '영웅이 없어 데미지가 들어가지 않았습니다',
    // 로비 스테이지 카드 — 이전 스테이지 표시.
    'lobby_previous_stage': '이전 스테이지',
    'shop_per_hero': '인당',
    // 영웅별 HUD 라벨 — **요소별 스킬**이라 요소마다 하나씩이다.
    'battle_hero_skill_fire_a': '전소각',
    'battle_hero_skill_water_a': '물폭탄',
    'battle_hero_skill_grass_a': '치유',
    'battle_hero_skill_light_a': '폭발',
    'battle_hero_skill_poison_a': '연소 폭발',
    // 스킬이 없는 영웅의 전투 캡션 (상세 다이얼로그의 문장 키와 구분).
    'battle_skill_none': '스킬 없음',
    // 스킬 설명 팝업 하단 — 사용 횟수 안내.
    'battle_skill_once': '스테이지당 1회',

    // 결과
    'result_victory': '🎉 승리!',
    'result_defeat': '💀 패배',
    'result_clear': '스테이지 {n} 클리어!',
    'result_defeated': '스테이지 {n}에서 패배했습니다.',
    'result_game_win': '획득 게임 재화',
    'result_game_loss': '게임 재화 (패배 시 보상 없음)',
    'result_attack': '⚔ 공격력 {n}',
    'result_damage_analysis': '전투 피해 분석',
    'result_damage_dealt': '가한 피해',
    'result_damage_received': '받은 피해',
    'result_largest_hit': '최대 단일 타격',
    'result_damage_sources': '피해 출처별 (횟수 × 합계)',
    'result_incoming_breakdowns': '피격 산출 내역',
    'result_party_stat_breakdown': '영웅별 최종 스탯',
    'result_stat_breakdown_legend':
        '영웅 개인 공격력이 그 색 룬 데미지에 그대로 합산 · DEF 가 높으면 몬스터 반격 감소',
    'damage_source_runeMatch': '룬 매치',
    'damage_source_heroSkill': '영웅 스킬',
    'damage_source_poisonTick': '독 스택',
    'damage_source_blackRune': '검은 룬 피격',
    'damage_source_monsterAttack': '몬스터 공격',
    'damage_source_bossUltimate': '보스 궁극기',
    'damage_total': '매칭 합계',
    'damage_overflow': '+{n}건 · {d}',
    'result_btn_next': '다음 스테이지 ▶',
    'result_btn_retry': '재도전 (Play {n})',
    'result_btn_shop': '상점으로 (성장 후 재도전)',
    'result_btn_lobby': '로비로 이동',

    // 튜토리얼
    'tutorial_title': '🎓 튜토리얼',
    'tutorial_skip': '건너뛰기',
    'tutorial_help': '도움말',
    'tutorial_step': 'STEP {current} / {total}',
    'tutorial_step_tag': 'STEP {current} · {id}',
    'tutorial_hint': '💡 힌트: {from} ⇄ {to} 스와이프',
    'tutorial_tile_label': '({col}열, {row}행)',
    'tutorial_skill_tap': '영웅 초상화를 눌러 스킬 사용',
    'tutorial_skill_tap_target': '초상화를 누른 뒤 보드의 룬을 눌러 조준',
    'tutorial_skip_dialog_title': '튜토리얼 건너뛰기',
    'tutorial_skip_dialog_msg': '아직 배우지 못한 부분이 있을 수 있어요.\n정말 건너뛸까요?',
    'tutorial_continue': '계속하기',
    'tutorial_title_match': '같은 룬 3개를 맞춰보세요',
    'tutorial_msg_match':
        '보드에서 🔥 Fire 룬 3개가 세로로 모여 있어요.\n'
        '한 룬을 옆/아래 룬과 스와이프하면 3개가 터지며 몬스터를 공격합니다!',
    'tutorial_title_affinity': '몬스터의 약점을 노리세요',
    'tutorial_msg_affinity':
        '데미지는 "그 색 살아있는 영웅의 공격력 합" × 콤보 × 상성입니다.\n'
        '이번 몬스터는 🔥 불에 약하므로 ×1.5 배가 붙습니다. Fire 3개를 터트려 보세요.',
    'tutorial_title_combo': '연쇄가 일어나면 콤보!',
    'tutorial_msg_combo':
        '매치 후 룬이 떨어지며 다시 3개가 모이면 COMBO!\n'
        '콤보가 오를 때마다 데미지 +20%. 보드 위쪽 GGG를 남겨두고 스와이프해 보세요.',
    'tutorial_title_monster': '턴이 끝나면 몬스터가 공격',
    'tutorial_msg_monster':
        '한 번의 스와이프 후 턴이 끝나면 몬스터가 공격합니다.\n'
        '내 체력(🛡 파티)이 깎이는 걸 확인해 보세요.',
    'tutorial_title_black-danger': '🖤 Black은 위험합니다',
    'tutorial_msg_black-danger':
        '검은 룬(Black) 3개 이상이 매치되면 파티가 피해를 입습니다!\n'
        '지금 보드에 Black 3개가 붙어 있어요. 스와이프하면 피해를 볼 수 있습니다… 조심하세요.',
    'tutorial_title_black-4-line': 'Black 4개는 피해 + 같은 줄 정화!',
    'tutorial_msg_black-4-line':
        'Black 4개가 매치되면 파티가 피해를 입고, 같은 줄의 나머지 Black까지 정화됩니다.\n'
        '지금 보드에 Black 4개 + 정화될 Black 1개가 있어요. 스와이프해서 확인해 보세요.',
    'tutorial_title_black-purge': 'Black 5개를 모으면 정화!',
    'tutorial_msg_black-purge':
        'Black 5개를 한 줄로 만들면 피해 없이 보드의 모든 Black을 정화합니다.\n'
        '아래 보드에 Black 5개가 이미 있어요. 건드리지 말고 다른 룬을 스와이프해 보세요.',
    'tutorial_title_skill': '영웅 스킬 사용하기',
    'tutorial_msg_skill':
        '영웅 초상화를 눌러 해당 영웅의 스킬을 사용하세요.\n'
        '각 영웅은 스테이지당 1회 사용할 수 있습니다. 내 턴마다 파티 전체에서 '
        '1회만 사용할 수 있고, 사용하면 몬스터가 반격합니다.',
    'tutorial_title_boss': '마지막! 보스를 쓰러뜨리세요',
    'tutorial_msg_boss':
        '🔥 Fire 3개를 맞춰 보스를 격파하면 튜토리얼 완료!\n'
        '배틀 승리 시 게임 재화 보상을 얻고 다음 스테이지로 진행합니다.',

    // 첫 패배 동료 영입 가이드
    'guide_name': '안내자',
    'guide_first_defeat_msg':
        '동료가 부족해서 쓰러진 거예요.\n'
        '제가 도와드릴게요 — 이걸로 동료 한 명을 뽑아보세요.',
    'guide_first_defeat_cta': '동료 영입하러 가기',
    'guide_first_defeat_cancel': '나중에',
    'guide_shop_banner': '아래 1연차 영입을 눌러 새 동료를 뽑아보세요!',
    'guide_pull_done_msg':
        '이제 함께 싸울 동료가 생겼어요.\n'
        '다시 도전해볼까요?',
    'guide_pull_done_cta': '로비로 가서 재도전',

    // 요소명 (RuneElement.name → 번역)
    'element_fire': '불',
    'element_grass': '풀',
    'element_water': '물',
    'element_light': '번개',
    'element_poison': '독',
    'element_black': '검은 룬',
  };

  // ─────────────────────────────────────────────────────────────
  // 日本語 (ja)
  // ─────────────────────────────────────────────────────────────
  static const Map<String, String> _ja = {
    // 共通
    'common_cancel': 'キャンセル',
    'common_retry': '再試行',
    'currency_game': '⚡ {n}',
    'currency_play': '🎟 {n}',
    'currency_hero': '⭐ {n}',
    'common_stage': 'STAGE {n}',

    // タイトル画面
    'title_subtitle': 'ルーン パズル タクティクス',
    'title_start': 'バトル開始',

    // 下部ナビゲーション
    'nav_lobby': 'ロビー',
    'nav_party': 'パーティ',
    'nav_shop': 'ショップ',
    'nav_settings': '設定',

    // メインハブ
    'main_load_error': 'セーブデータを読み込めませんでした。',
    'main_reset_done': '進行度が初期化されました。',
    'exit_confirm': '戻るをもう一度押すと終了します。',

    // ロビー
    'lobby_mode_title': '🧩 RUNEモード',
    'lobby_best_clear': '最高クリア',
    'lobby_record': '戦績',
    'lobby_record_value': '{wins}勝 {losses}敗',
    'lobby_battle_start': 'バトル開始 (STAGE {n})',
    'entry_cost_label': '入場コスト: 🎟 {n}',
    'entry_error_no_play': 'プレイ通貨が不足しています。(必要 {n} 🎟)',
    'entry_short_title': 'プレイ通貨が不足',
    'entry_short_watch_ad': '広告を見る (+{n} 🎟)',
    'entry_short_go_shop': 'ショップへ移動',
    'daily_reward_title': '🎁 デイリー報酬',
    'daily_reward_desc': '🎟 +{play} · ⭐ +{hero} (1日1回)',
    'daily_reward_claim': '受け取る',
    'daily_reward_claimed': '本日受取済み',
    'ad_reward_play': '▶ 広告視聴: +{n} 🎟',
    'ad_reward_hero': '▶ 広告視聴: +{n} ⭐',
    'ad_load_failed': '広告を読み込めませんでした。しばらくしてからもう一度お試しください。',
    'ad_play_owned': 'プレイチケットは既に所持しています。',
    'ad_hero_daily_done': 'ヒーロー広告の報酬は明日また受け取れます。',
    'ad_reward_granted': '+{n} の報酬を受け取りました！',
    'lobby_view_upgrades': '恒久アップグレードを見る',
    'party_summary': '現在のパーティ',
    'hero_owned': '所持 {n}',

    // 属性の人数表示（倍率は付けない — 攻撃力の合計がそのままダメージの土台になる）
    'party_count_unit': '{n}人',

    // パーティ
    'party_title': '👥 パーティ管理',
    'party_counter': 'パーティ {total} / {max}',
    'party_desc':
        'ルーンマッチのダメージは「その属性の生存ヒーローの攻撃力合計」× コンボ × 相性 です。同じ属性のヒーローを多く入れるとその属性のダメージが自動で上がります。',
    'party_recruit_hint': '💡 ヒーローの勧誘はショップタブでヒーロー通貨(⭐)を使って行えます。',
    'party_unassign_tooltip': 'パーティから外す',
    'party_assign_tooltip': 'パーティに編成',
    'party_assign_confirm_title': 'ヒーロー加入',
    'party_assign_confirm_message': '{hero}をパーティに加入させますか？',
    'party_assign_yes': 'はい',
    'party_assign_no': 'いいえ',
    'party_in_party': '編成',
    'party_tab_all': 'パーティ',
    'party_empty_hint': '所有する英雄がいません。ショップで英雄を入手してください。',
    'party_slot_add_tooltip': 'タップして英雄を編成',
    'party_slots_full': 'パーティが満員です (5/5)',
    'party_synergy_none': 'パーティに英雄がいません',
    'party_picker_title': '英雄を選択',
    'party_picker_counter': 'パーティ {total} / {max}',
    'party_picker_assigned': '編成中',
    'party_picker_empty': '編成できる英雄がいません。ショップで入手してください。',
    'party_picker_hint': 'ヒーローをタップしてパーティに参加させます。',
    'party_unassign_confirm_title': 'パーティから外す',
    'party_unassign_confirm_message': '{hero}をパーティから外しますか？',
    'hero_name_fire_a': 'エンバー',
    'hero_name_grass_a': 'リアナ',
    'hero_name_water_a': 'マリス',
    'hero_name_light_a': 'ルミア',
    'hero_name_poison_a': 'ニクス',

    // ヒーロー詳細ポップアップ / ヒーロー図鑑
    'hero_detail_desc_label': '説明',
    'hero_detail_skill_label': 'ヒーロースキル',
    'hero_skill_none': 'このヒーローにスキルはありません。',
    // ヒーロー別スキル詳細 — **属性別スキル**（属性ごとに1種、属性ごとにヒーロー1名）。
    'hero_skill_fire_a': 'ステージごとに1回：ルーンを1つ選ぶと、その色のルーンが盤面すべて火ルーンになります。',
    'hero_skill_water_a': 'ステージごとに1回：盤面の水ルーン1個につき10の直接ダメージを与えます。',
    'hero_skill_grass_a': 'ステージごとに1回：盤面の草ルーン1個につき10ずつパーティを回復します。',
    'hero_skill_light_a': 'ステージごとに1回：好きなルーンを選ぶと、そのマスの3×3範囲が爆発し、残りが落ちます。',
    'hero_skill_poison_a':
        'ステージごとに1回：盤面の毒ルーンをすべて焼き払い、消した数だけ10ずつ即時ダメージを与えます。残りが落ちます。',
    'hero_state_not_owned': '未所持',
    'hero_detail_starter': 'スターター（無料）',
    'hero_detail_stats_label': '基本ステータス',
    'stat_hp': 'HP',
    'stat_atk': 'ATK',
    'stat_def': 'DEF',
    'hero_detail_open': '詳細',
    'hero_level_label': 'レベル',
    'hero_level_bonus': 'レベルボーナス',
    'hero_level_max': 'MAX',
    'hero_exp_progress': '{exp} / {next} EXP',
    'result_level_up_title': '⬆ レベルアップ',
    'result_level_up_line': 'Lv.{from} → Lv.{to}',
    'result_hero_exp_title': 'ヒーロー成長',
    'result_hero_exp_gain': '+{n} EXP',

    // 等級の説明用。UIの表示は星の数で表す。
    'rarity_r': 'コモン',
    'rarity_sr': 'レア',
    'rarity_ssr': 'エピック',
    'rarity_ur': 'レジェンダリー',

    // ヒーロー抽選（ガチャ）
    'gacha_header': 'ヒーロー勧誘（ヒーロー通貨 ⭐）',
    'gacha_single': '1連ガチャ',
    'gacha_ten': '10連ガチャ',
    'gacha_cost': '⭐{n}',
    'gacha_rates_header': '等級の確率',
    'gacha_rates_note':
        '高い等級はステージ進行で解放されます。'
        '重複したヒーローは保有中の最高等級が吸収します。',
    'gacha_codex_progress': '所持ヒーロー {owned} / {total}',
    'gacha_badge_new': 'NEW',
    'gacha_badge_promote': '等級アップ',
    'gacha_badge_levelup': 'レベルアップ',
    'gacha_badge_max': '最高等級',
    'gacha_promote_to': '{from} → {to}',
    'gacha_confirm': '確認',
    'gacha_error_hero': 'ヒーロー通貨が不足しています。（{n} ⭐ 必要）',
    'gacha_error_hero_count': 'ヒーロー通貨が不足しています。（{count}連に {n} ⭐ 必要）',
    'gacha_empty_pool': 'まだ勧誘できるヒーローがありません。',
    'hero_codex_title': '📖 ヒーロー図鑑',
    'hero_codex_desc': '全5人のヒーローです。ヒーローをタップすると説明とスキルを確認できます。',
    'hero_desc_fire_a': '最初の炎のヒーロー。燃え上がるルーンの流れを自然に取り扱い、爆発オーブの扱いは誰よりも得意です。',
    'hero_desc_grass_a': '誰よりも先にパーティの体力を読み取る治癒者。炎が焼いた痕を草で静かに覆います。',
    'hero_desc_water_a': '表は静か、底は底知れなく。盤から黒い残滓を洗い流すのはこの役目です。',
    'hero_desc_light_a': 'まだ自分の光が何のためにあるのか学んでいない明るい魂。それでもパーティの先頭を守り、立っています。',
    'hero_desc_poison_a': '素手で毒を扱うながら、パーティの体力はほとんど揺らぎません。厳しい道を歩み始めた者です。',

    // ショップ
    'shop_title': '🛒 ショップ',
    'shop_upgrades_header': 'パーティ能力の書・強化',
    'shop_owned_badge': '所持',
    'shop_locked_unlock': 'ステージ{n}で解放',
    'shop_error_max_level': 'すでに最大レベルです。',
    'shop_error_game': 'ゲーム通貨が不足しています。(必要 {n} ⚡)',
    'shop_effect': '効果: {label}',
    'shop_max_level': '最大レベル',
    'shop_buy': '購入 {n}⚡',
    'shop_lv': 'Lv. {level} / {max}',
    'book_level': 'Lv. {level}',
    'book_purchase_success': '魔導書を強化しました。パーティ能力が上昇！',
    'book_name_hp': '生命の書',
    'book_name_atk': '闘志の書',
    'book_name_def': '守護の書',
    'book_name_affinity_bonus': '破砕の書',
    'book_name_affinity_resistance': '結界の書',
    'book_stat_hp': 'パーティHP',
    'book_stat_atk': 'パーティATK',
    'book_stat_def': 'パーティDEF',

    // アップグレード
    'upgrade_name_partyAttack': 'パーティ攻撃力',
    'upgrade_name_partyMaxHp': 'パーティ最大HP',
    'upgrade_name_gameGain': 'ゲーム通貨獲得',
    'upgrade_desc_partyAttack': '戦闘基本攻撃力(Party Base Attack)がレベルごとに+10増加します。',
    'upgrade_desc_partyMaxHp': 'パーティ最大HPがレベルごとに+10増加します。',
    'upgrade_desc_gameGain': '勝利時の獲得ゲーム通貨がレベルごとに+10%増加します。',
    'upgrade_effect_partyAttack': '攻撃力',
    'upgrade_effect_partyMaxHp': '最大HP',
    'upgrade_effect_gameGain': 'ゲーム通貨獲得',

    // 設定
    'settings_title': '⚙ 設定',
    'settings_section_tutorial': 'チュートリアル',
    'settings_replay_tutorial': 'チュートリアルを見る',
    'settings_audio': 'オーディオ',
    'settings_music': 'BGM',
    'settings_sound_effects': '効果音',
    'settings_section_data': 'データ',
    'settings_reset_progress': '進行度をリセット',
    'settings_language': '言語',
    'settings_language_select': '言語を選択',
    'settings_language_current': '現在の言語: {name}',
    'settings_reset_dialog_title': '進行度をリセット',
    'settings_reset_dialog_msg': 'すべての通貨・クリア・アップグレード・パーティが削除されます。\n続行しますか？',
    'settings_reset_confirm': 'リセット',
    'settings_footer':
        'Rune Puzzle Tactics v0.8\nローカル保存 (SQLite) · '
        'Firebase Analytics 連携準備',

    // アプリ情報 (要件10)
    'common_close': '閉じる',
    'settings_section_about': 'アプリ情報',
    'settings_credits': 'クレジット',
    'settings_rate_app': '評価する',
    'settings_other_apps': '他のアプリを見る',
    'settings_coming_soon': '準備中',
    'credits_title': 'クレジット',
    'credits_version': 'バージョン {version}',
    'credits_role_dev': '開発・デザイン — Rune Puzzle Tactics チーム',
    'credits_role_art': 'アート — ドット絵＆カード画像パック',
    'credits_role_sound': 'サウンド — BFXR サウンドパック',
    'credits_role_thanks': '遊んでくれてありがとう！',

    // 最後にプレイしたステージ (要件1)
    'lobby_last_played': '前回のプレイ',
    'lobby_last_result_win': 'クリア成功',
    'lobby_last_result_lose': '敗北 — 再挑戦',

    // パーティ `+` の無効理由 (要件5)
    'party_slots_nothing_to_add': '保有ヒーローはすべて編成済みです',

    // ヒーロー図鑑グリッド (要件6)
    'codex_owned_count': '保有 {owned} / {total}',

    // ヒーローガチャ天井 (要件9)
    'gacha_pity_progress': ' 신규確定まであと {n} 回',
    'gacha_pity_counter': '連続重複 {count} / {max}',
    'gacha_pity_ready': '天井発動！次の1回は新規確定',
    'gacha_pity_note': '重複を重ねると上昇します。10連には適用されません。',
    'gacha_skip': 'スキップ',
    'gacha_congrats_new': '新規ヒーロー！',
    'gacha_ten_no_new': '今回は新規ヒーローができませんでした',

    // 言語選択ダイアログ
    'lang_dialog_title': '言語を選択',
    'lang_en': 'English',
    'lang_ko': '한국어',
    'lang_ja': '日本語',
    'lang_zh_hans': '简体中文',
    'lang_zh_hant': '繁體中文',

    // バトル
    'battle_leave_tooltip': '離脱',
    'battle_type_boss': 'ボス',
    'battle_boss_ultimate_warning': '⚠ 次の攻撃は必殺技！',
    'battle_type_elite': 'エリート',
    'battle_type_normal': 'ノーマル',
    'battle_pause_tooltip': '一時停止',
    'turn_monster': '⚠ モンスターのターン',
    'turn_victory': '🏆 勝利',
    'turn_defeat': '💀 敗北',
    'turn_retreat': '離脱',
    'turn_player': '▶ プレイヤーのターン',
    'hp_party': '🛡 パーティ',
    'hp_monster': '👹 モンスター',
    'combo': 'COMBO x{n}',
    'battle_paused': '一時停止',
    'battle_resume': '再開',
    'battle_restart': 'やり直す',
    'battle_go_lobby': 'ロビーへ',
    'battle_ready_go': 'Ready... GO!',

    // ステージ準備 (入場前確認, 要件 6.1)
    'stage_prep_title': 'ステージ準備',
    'stage_prep_monster_count': 'モンスター {n}体',
    'stage_prep_party': '出撃パーティ',
    'stage_prep_confirm': '出撃',
    'stage_prep_play_held': '/ 所持 {n}',
    'stage_prep_info_body':
        'モンスターに属性はありませんが、ステージごとに弱点(×1.5)属性と'
        '耐性(×0.5)属性があります。ルーンマッチのダメージは'
        '「その属性の生存ヒーローの攻撃力合計」× コンボ × 相性 です。\n'
        '空きスロット(+)をタップしてヒーローを編成できます。'
        'ヒーローのポートレートをタップしてスキルを使います。各ヒーローは'
        'ステージごとに1回、プレイヤーのターンごとにパーティ全体で1回だけ'
        '使用できます。',
    'incoming_damage_formula':
        'ATK {atk} × 100 / (100 + DEF {def}) = -{damage}; '
        'HP {hpBefore}→{hpAfter}/{hpMax}',

    // モンスター相性 (モンスターに属性なし — 弱点/耐性は現在出現中のモンスター基準)
    'battle_monster_weak': '弱点',
    'battle_monster_resist': '耐性',
    // 波状戦闘 — モンスターが順番に出現する (現在 n / 全 N)。
    'battle_monster_wave': 'モンスター {i}/{n}',

    // 波状撃破報酬 — モンスター撃破でパーティHP回復 + スキル回復(1人)
    'wave_reward_title': 'モンスター撃破！',
    'wave_reward_heal': 'パーティHP +{n} 回復',
    'wave_reward_skill': 'スキル回復（1人）',
    'wave_reward_skip': 'スキップ',

    // ロビーステージカード / パーティ概要 (仕様 1-1)
    'lobby_stage_progress': '進入上限 {cleared}',
    'lobby_max_stage_banner': '最終ステージに到達！再挑戦できます。',
    'lobby_current_party': '出撃パーティ',
    'lobby_party_stats': '英雄ステータス',
    'lobby_party_defense': 'パーティDEF',
    'lobby_upgrade_levels': '永続アップグレード',

    // ヒーロースキル
    'battle_skill_used': '使用済み',
    // 対象指定スキル（火/光）で盤面の対象マスを選んでいる状態。
    'battle_skill_aiming': '狙撃',
    // マッチしたがその属性のヒーローがパーティにおらずダメージ0だった時の警告.
    'battle_no_element_hero': 'ヒーローがいないためダメージが入りませんでした',
    // ロビーステージカード — 前のステージ表示.
    'lobby_previous_stage': '前のステージ',
    // 쓰러진 영웅(초상화 하단 HP 0 → ✕ 오버레이)
    'battle_hero_down': '戦闘不能',
    'shop_per_hero': '1人あたり',
    // ヒーロー別HUDラベル — **属性別スキル**なので属性ごとに1つ。
    'battle_hero_skill_fire_a': '全焼',
    'battle_hero_skill_water_a': '潮流打撃',
    'battle_hero_skill_grass_a': '再生',
    'battle_hero_skill_light_a': '爆撃',
    'battle_hero_skill_poison_a': 'ベノムバースト',
    // スキルのないヒーローの戦闘キャプション（詳細ダイアログの文章キーとは区別）。
    'battle_skill_none': 'スキルなし',
    // スキル説明ポップアップ下部 — 使用回数案内。
    'battle_skill_once': 'ステージごとに1回',

    // 結果
    'result_victory': '🎉 勝利！',
    'result_defeat': '💀 敗北',
    'result_clear': 'ステージ {n} クリア！',
    'result_defeated': 'ステージ {n} で敗北しました。',
    'result_game_win': '獲得ゲーム通貨',
    'result_game_loss': 'ゲーム通貨 (敗北時は報酬なし)',
    'result_attack': '⚔ 攻撃力 {n}',
    'result_damage_analysis': '戦闘ダメージ分析',
    'result_damage_dealt': '与えたダメージ',
    'result_damage_received': '受けたダメージ',
    'result_largest_hit': '最大単発ダメージ',
    'result_damage_sources': 'ダメージ源別 (回数 × 合計)',
    'result_incoming_breakdowns': '被ダメージ計算',
    'result_party_stat_breakdown': '英雄別の最終ステータス',
    'result_stat_breakdown_legend':
        '各英雄の攻撃力はそのまま同属性ルーンのダメージに加算 · DEF が高いほど大幅反撃ダメージが減る',
    'damage_source_runeMatch': 'ルーンマッチ',
    'damage_source_heroSkill': 'ヒーロースキル',
    'damage_source_poisonTick': '毒スタック',
    'damage_source_blackRune': 'Blackルーン被弾',
    'damage_source_monsterAttack': 'モンスター攻撃',
    'damage_source_bossUltimate': 'ボス必殺技',
    'damage_total': 'マッチ合計',
    'damage_overflow': '+{n}件 · {d}',
    'result_btn_next': '次のステージ ▶',
    'result_btn_retry': '再挑戦 (Play {n})',
    'result_btn_shop': 'ショップへ (強化して再挑戦)',
    'result_btn_lobby': 'ロビーへ戻る',

    // チュートリアル
    'tutorial_title': '🎓 チュートリアル',
    'tutorial_skip': 'スキップ',
    'tutorial_help': 'ヘルプ',
    'tutorial_step': 'STEP {current} / {total}',
    'tutorial_step_tag': 'STEP {current} · {id}',
    'tutorial_hint': '💡 ヒント: {from} ⇄ {to} をスワイプ',
    'tutorial_tile_label': '({col}列, {row}行)',
    'tutorial_skill_tap': 'ヒーローのポートレートをタップしてスキルを使う',
    'tutorial_skill_tap_target': 'ポートレートを押してから盤面のルーンをタップして狙撃',
    'tutorial_skip_dialog_title': 'チュートリアルをスキップ',
    'tutorial_skip_dialog_msg': 'まだ学んでいない部分があるかもしれません。\n本当にスキップしますか？',
    'tutorial_continue': '続ける',
    'tutorial_title_match': '同じルーンを3つ揃えよう',
    'tutorial_msg_match':
        'ボードに 🔥 ファイアルーンが縦に3つ並んでいます。\n'
        'ルーンを隣のマスとスワイプして3つ揃えるとモンスターを攻撃できます！',
    'tutorial_title_affinity': 'モンスターの弱点を狙う',
    'tutorial_msg_affinity':
        'ダメージは「その属性の生存ヒーローの攻撃力合計」× コンボ × 相性 です。\n'
        'このモンスターは 🔥 炎に弱いので×1.5倍。ファイアルーンを3つ揃えましょう。',
    'tutorial_title_combo': '連鎖でコンボ！',
    'tutorial_msg_combo':
        'マッチ後にルーンが落ちて再び3つ揃うとコンボ！\n'
        'コンボが1上がるごとにダメージ+20%。ボード上部のGGGを残してスワイプしてみましょう。',
    'tutorial_title_monster': 'ターンが終わるとモンスターが攻撃',
    'tutorial_msg_monster':
        'スワイプ後にターンが終わるとモンスターが攻撃します。\n'
        '自分のHP(🛡 パーティ)が減ることを確認しましょう。',
    'tutorial_title_black-danger': '🖤 ブラックは危険',
    'tutorial_msg_black-danger':
        'ブラックルーンを3つ以上揃えるとパーティがダメージを受けます！\n'
        'ボードにブラックが3つ並んでいます。スワイプするとダメージを受けます…注意してください。',
    'tutorial_title_black-4-line': 'ブラック4つはダメージ+同列浄化！',
    'tutorial_msg_black-4-line':
        'ブラック4つを揃えるとパーティにダメージが入り、同じ列の他のブラックも浄化されます。\n'
        'ボードにはブラック4つ+浄化される1つがあります。スワイプして確認しましょう。',
    'tutorial_title_black-purge': 'ブラックを5つ揃えると浄化！',
    'tutorial_msg_black-purge':
        'ブラックを5つ一直線に揃えると、ダメージなしでボードのすべてのブラックを浄化します。\n'
        '下のボードにすでにブラックが5つあります。触らずに他のルーンをスワイプしましょう。',
    'tutorial_title_skill': 'ヒーロースキルを使おう',
    'tutorial_msg_skill':
        'ヒーローのポートレートをタップしてスキルを使いましょう。\n'
        '各ヒーローはステージごとに1回使用できます。プレイヤーのターンごとに'
        'パーティ全体で1回だけ使用でき、使用後はモンスターが反撃します。',
    'tutorial_title_boss': '最後！ボスを倒そう',
    'tutorial_msg_boss':
        '🔥 ファイアを3つ揃えてボスを倒すとチュートリアル完了！\n'
        'バトルに勝つとゲーム通貨報酬を得て次のステージに進みます。',

    // 初敗北・仲間募集ガイド
    'guide_name': '案内人',
    'guide_first_defeat_msg':
        '仲間が足りないから負けたんです。\n'
        '私が手伝います — これで仲間を1人引いてみてください。',
    'guide_first_defeat_cta': '仲間を募集する',
    'guide_first_defeat_cancel': 'あとで',
    'guide_shop_banner': '下の単発募集で新しい仲間を引いてみましょう！',
    'guide_pull_done_msg':
        '一緒に戦う仲間ができました。\n'
        'もう一度挑戦してみますか？',
    'guide_pull_done_cta': 'ロビーへ戻って再挑戦',

    // 元素名 (RuneElement.name → 翻訳)
    'element_fire': '炎',
    'element_grass': '草',
    'element_water': '水',
    'element_light': '稲妻',
    'element_poison': '毒',
    'element_black': 'ブラック',
  };

  // ─────────────────────────────────────────────────────────────
  // 简体中文 (zh-Hans)
  // ─────────────────────────────────────────────────────────────
  static const Map<String, String> _zhHans = {
    // 通用
    'common_cancel': '取消',
    'common_retry': '重试',
    'currency_game': '⚡ {n}',
    'currency_play': '🎟 {n}',
    'currency_hero': '⭐ {n}',
    'common_stage': 'STAGE {n}',

    // 标题画面
    'title_subtitle': '符文拼图战术',
    'title_start': '开始战斗',

    // 底部导航
    'nav_lobby': '大厅',
    'nav_party': '队伍',
    'nav_shop': '商店',
    'nav_settings': '设置',

    // 主大厅
    'main_load_error': '无法读取存档数据。',
    'main_reset_done': '进度已重置。',
    'exit_confirm': '再按一次返回键退出',

    // 大厅
    'lobby_mode_title': '🧩 RUNE 模式',
    'lobby_best_clear': '最高通关',
    'lobby_record': '战绩',
    'lobby_record_value': '{wins}胜 {losses}负',
    'lobby_battle_start': '开始战斗 (STAGE {n})',
    'entry_cost_label': '入场费用: 🎟 {n}',
    'entry_error_no_play': 'Play货币不足。(需要 {n} 🎟)',
    'entry_short_title': 'Play货币不足',
    'entry_short_watch_ad': '观看广告 (+{n} 🎟)',
    'entry_short_go_shop': '前往商店',
    'daily_reward_title': '🎁 每日奖励',
    'daily_reward_desc': '🎟 +{play} · ⭐ +{hero} (每日1次)',
    'daily_reward_claim': '领取',
    'daily_reward_claimed': '今日已领取',
    'ad_reward_play': '▶ 观看广告: +{n} 🎟',
    'ad_reward_hero': '▶ 观看广告: +{n} ⭐',
    'ad_load_failed': '无法加载广告，请稍后再试。',
    'ad_play_owned': '你已拥有Play券。',
    'ad_hero_daily_done': '英雄广告奖励明天可再次领取。',
    'ad_reward_granted': '已获得 +{n} 奖励！',
    'lobby_view_upgrades': '查看永久强化',
    'party_summary': '当前队伍',
    'hero_owned': '已拥有 {n}',

    // 属性人数显示（不含倍率 —— 攻击力之和即为伤害基数）
    'party_count_unit': '{n}',

    // 队伍
    'party_title': '👥 队伍管理',
    'party_counter': '队伍 {total} / {max}',
    'party_desc':
        '符文连消的伤害等于“该属性存活英雄的攻击力之和”×连击×属性克制。'
        '因此同属性的英雄越多，该颜色的伤害就越高。',
    'party_recruit_hint': '💡 可在商店标签中使用英雄货币(⭐)招募英雄。',
    'party_unassign_tooltip': '从队伍中移除',
    'party_assign_tooltip': '加入队伍',
    'party_assign_confirm_title': '英雄加入',
    'party_assign_confirm_message': '要将 {hero} 加入队伍吗？',
    'party_assign_yes': '是',
    'party_assign_no': '否',
    'party_in_party': '已编入',
    'party_tab_all': '队伍',
    'party_empty_hint': '还没有拥有英雄。请到商店标签招募。',
    'party_slot_add_tooltip': '点击编入英雄',
    'party_slots_full': '队伍已满 (5/5)',
    'party_synergy_none': '队伍中没有英雄',
    'party_picker_title': '选择英雄',
    'party_picker_counter': '队伍 {total} / {max}',
    'party_picker_assigned': '已编入',
    'party_picker_empty': '没有可编入的英雄。请到商店招募。',
    'party_picker_hint': '点击英雄即可将其加入队伍。',
    'party_unassign_confirm_title': '从队伍中移除',
    'party_unassign_confirm_message': '要将 {hero} 从队伍中移除吗？',
    'hero_name_fire_a': '恩伯',
    'hero_name_grass_a': '莉安娜',
    'hero_name_water_a': '玛丽斯',
    'hero_name_light_a': '露米娅',
    'hero_name_poison_a': '尼克斯',

    // 英雄详情弹窗 / 英雄图鉴
    'hero_detail_desc_label': '描述',
    'hero_detail_skill_label': '英雄技能',
    'hero_skill_none': '该英雄没有技能。',
    // 各英雄技能详情 —— 按元素区分技能（每种属性1个技能，每种属性1名英雄）。
    'hero_skill_fire_a': '每关1次：选择一枚符文，棋盘上所有该颜色的符文都会变为火焰符文。',
    'hero_skill_water_a': '每关1次：棋盘上每有一枚水符文，造成10点直接伤害。',
    'hero_skill_grass_a': '每关1次：棋盘上每有一枚草符文，为队伍恢复10点HP。',
    'hero_skill_light_a': '每关1次：选择任意一枚符文，其周围3×3区域爆炸，其余符文下落。',
    'hero_skill_poison_a': '每关1次：烧尽棋盘上所有毒符文，每清除一枚造成10点伤害。其余符文下落。',
    'hero_state_not_owned': '未拥有',
    'hero_detail_starter': '初始(免费)',
    'hero_detail_stats_label': '基础属性',
    'stat_hp': 'HP',
    'stat_atk': 'ATK',
    'stat_def': 'DEF',
    'hero_detail_open': '详情',
    'hero_level_label': '等级',
    'hero_level_bonus': '等级加成',
    'hero_level_max': 'MAX',
    'hero_exp_progress': '{exp} / {next} EXP',
    'result_level_up_title': '⬆ 升级',
    'result_level_up_line': 'Lv.{from} → Lv.{to}',
    'result_hero_exp_title': '英雄成长',
    'result_hero_exp_gain': '+{n} EXP',

    // 稀有度说明为辅助信息，UI 以星数显示。
    'rarity_r': '普通',
    'rarity_sr': '稀有',
    'rarity_ssr': '史诗',
    'rarity_ur': '传说',

    // 英雄招募（抽卡）
    'gacha_header': '英雄招募 (英雄货币 ⭐)',
    'gacha_single': '1连抽',
    'gacha_ten': '10连抽',
    'gacha_cost': '⭐{n}',
    'gacha_rates_header': '概率',
    'gacha_rates_note': '更高稀有度随关卡推进解锁。重复英雄会被你已拥有的最高稀有度英雄吸收。',
    'gacha_codex_progress': '已拥有英雄 {owned} / {total}',
    'gacha_badge_new': '新',
    'gacha_badge_promote': '升阶',
    'gacha_badge_levelup': '升级',
    'gacha_badge_max': '最高阶',
    'gacha_promote_to': '{from} → {to}',
    'gacha_confirm': '确认',
    'gacha_error_hero': '英雄货币不足。(需要 {n} ⭐)',
    'gacha_error_hero_count': '英雄货币不足。({count}连需要 {n} ⭐)',
    'gacha_empty_pool': '暂无可招募的英雄。',
    'hero_codex_title': '📖 英雄图鉴',
    'hero_codex_desc': '共有5名英雄。点击任意英雄即可查看其描述与技能。',
    'hero_desc_fire_a': '最初的火焰英雄。她操纵燃烧的符文如同呼吸一般自然，是最擅长操控爆炸宝珠的人。',
    'hero_desc_grass_a': '在任何人开口之前就读懂队伍体力的治疗者。她用草之力静静填补被火焰烧灼的痕迹。',
    'hero_desc_water_a': '表面平静、底下却深不见底的水流。洗去棋盘上的黑色残渣，是她的职责。',
    'hero_desc_light_a': '尚未学会自己的光为何而亮的明亮灵魂。即便如此，她仍站在队伍最前方守住阵线。',
    'hero_desc_poison_a': '徒手操控剧毒，队伍的生命却几乎不为所动。这是踏入艰险之路的第一步。',

    // 商店
    'shop_title': '🛒 商店',
    'shop_upgrades_header': '队伍属性魔导书与强化',
    'shop_owned_badge': '已拥有',
    'shop_locked_unlock': '第 {n} 关解锁',
    'shop_error_max_level': '已达到最高等级。',
    'shop_error_game': '游戏货币不足。(需要 {n} ⚡)',
    'shop_effect': '效果: {label}',
    'shop_max_level': '最高等级',
    'shop_buy': '购买 ({n} ⚡)',
    'shop_lv': 'Lv. {level} / {max}',
    'book_level': 'Lv. {level}',
    'book_purchase_success': '魔导书强化完成！队伍属性得到提升。',
    'book_name_hp': '生命之书',
    'book_name_atk': '斗志之书',
    'book_name_def': '守护之书',
    'book_name_affinity_bonus': '破裂之书',
    'book_name_affinity_resistance': '结界之书',
    'book_stat_hp': '队伍HP',
    'book_stat_atk': '队伍ATK',
    'book_stat_def': '队伍DEF',

    // 升级
    'upgrade_name_partyAttack': '队伍攻击力',
    'upgrade_name_partyMaxHp': '队伍最大HP',
    'upgrade_name_gameGain': '游戏货币获取',
    'upgrade_desc_partyAttack': '战斗基础攻击力(Party Base Attack)每级 +10。',
    'upgrade_desc_partyMaxHp': '队伍最大HP每级 +10。',
    'upgrade_desc_gameGain': '胜利时获取的游戏货币每级 +10%。',
    'upgrade_effect_partyAttack': '攻击力',
    'upgrade_effect_partyMaxHp': '最大HP',
    'upgrade_effect_gameGain': '游戏货币获取',

    // 设置
    'settings_title': '⚙ 设置',
    'settings_section_tutorial': '教程',
    'settings_replay_tutorial': '重看教程',
    'settings_audio': '音频',
    'settings_music': '背景音乐',
    'settings_sound_effects': '音效',
    'settings_section_data': '数据',
    'settings_reset_progress': '重置进度',
    'settings_language': '语言',
    'settings_language_select': '选择语言',
    'settings_language_current': '当前语言: {name}',
    'settings_reset_dialog_title': '重置进度',
    'settings_reset_dialog_msg': '所有货币/通关/强化/队伍都将被删除。\n继续吗？',
    'settings_reset_confirm': '重置',
    'settings_footer':
        'Rune Puzzle Tactics v0.8\n本地存档(SQLite) · Firebase Analytics 已就绪',

    // 应用信息
    'common_close': '关闭',
    'settings_section_about': '关于',
    'settings_credits': '制作人员',
    'settings_rate_app': '评价应用',
    'settings_other_apps': '浏览其他应用',
    'settings_coming_soon': '敬请期待',
    'credits_title': '制作人员',
    'credits_version': '版本 {version}',
    'credits_role_dev': '开发与设计 — Rune Puzzle Tactics 团队',
    'credits_role_art': '美术 — 像素与卡牌图片包',
    'credits_role_sound': '音效 — BFXR 音效包',
    'credits_role_thanks': '感谢游玩！',

    // 上次游玩的关卡
    'lobby_last_played': '上次游玩',
    'lobby_last_result_win': '通关成功',
    'lobby_last_result_lose': '失败 — 再挑战一次',

    // 队伍 `+` 不可用时的说明
    'party_slots_nothing_to_add': '已编入全部拥有的英雄',

    // 英雄图鉴网格
    'codex_owned_count': '已拥有 {owned} / {total}',

    // 英雄招募保底
    'gacha_pity_progress': '再抽 {n} 次单抽必得新英雄',
    'gacha_pity_counter': '连续重复 {count} / {max}',
    'gacha_pity_ready': '保底就绪 — 下次单抽必为新英雄',
    'gacha_pity_note': '重复次数越多累积越高。10连抽不受影响。',
    'gacha_skip': '跳过',
    'gacha_congrats_new': '新英雄登场！',
    'gacha_ten_no_new': '这次没有新英雄',

    // 语言选择对话框
    'lang_dialog_title': '选择语言',
    'lang_en': 'English',
    'lang_ko': '한국어',
    'lang_ja': '日本語',
    'lang_zh_hans': '简体中文',
    'lang_zh_hant': '繁體中文',

    // 战斗
    'battle_leave_tooltip': '退出',
    'battle_type_boss': '首领',
    'battle_boss_ultimate_warning': '⚠ 下一击是终极技！',
    'battle_type_elite': '精英',
    'battle_type_normal': '普通',
    'battle_pause_tooltip': '暂停',
    'turn_monster': '⚠ 怪物回合',
    'turn_victory': '🏆 胜利',
    'turn_defeat': '💀 失败',
    'turn_retreat': '退出',
    'turn_player': '▶ 玩家回合',
    'hp_party': '🛡 队伍',
    'hp_monster': '👹 怪物',
    'combo': 'COMBO x{n}',
    'battle_paused': '已暂停',
    'battle_resume': '继续',
    'battle_restart': '重新开始',
    'battle_go_lobby': '前往大厅',
    'battle_ready_go': 'Ready... GO!',

    // 关卡准备（进入前确认）
    'stage_prep_title': '关卡准备',
    'stage_prep_monster_count': '怪物 {n}只',
    'stage_prep_party': '出战队伍',
    'stage_prep_confirm': '开始战斗',
    'stage_prep_play_held': '/ 持有 {n}',
    'stage_prep_info_body':
        '怪物无属性，但每个关卡都有弱点(×1.5)属性与劣势(×0.5)属性。'
        '符文连消的伤害等于“该属性存活英雄攻击力之和”×连击×属性克制。\n'
        '点击空位(+)可编入英雄。点击英雄头像即可使用技能。每个英雄每关可使用1次，'
        '且每个玩家回合全队只能使用1次。',
    'incoming_damage_formula':
        'ATK {atk} × 100 / (100 + DEF {def}) = -{damage}; '
        'HP {hpBefore}→{hpAfter}/{hpMax}',

    // 怪物属性克制（怪物无属性 —— 弱点/劣势以当前怪物为准）
    'battle_monster_weak': '弱点',
    'battle_monster_resist': '劣势',
    // 波次战斗 —— 怪物按顺序登场（当前 i / 共 n）。
    'battle_monster_wave': '怪物 {i}/{n}',

    // 波次奖励 —— 击败怪物后队伍HP恢复 + 技能充能(1名)
    'wave_reward_title': '击败怪物！',
    'wave_reward_heal': '队伍HP +{n} 恢复',
    'wave_reward_skill': '技能充能 (1名)',
    'wave_reward_skip': '跳过',

    // 大厅关卡卡片 / 队伍摘要
    'lobby_stage_progress': '最高进入 {cleared}',
    'lobby_max_stage_banner': '已到达最终关卡！可以重新挑战。',
    'lobby_current_party': '出战队伍',
    'lobby_party_stats': '英雄属性',
    'lobby_party_defense': '队伍DEF',
    'lobby_upgrade_levels': '永久强化',

    // 英雄技能
    'battle_skill_used': '已使用',
    // 标记型技能(Fire/Light)正在选择棋盘目标格。
    'battle_skill_aiming': '瞄准',
    // 倒下的英雄（头像下方HP 0 → ✕ 覆盖层）
    'battle_hero_down': '倒下',
    // 连消成功但队伍中没有该属性英雄，伤害为0时的怪物中央警告。
    'battle_no_element_hero': '队伍中没有该属性英雄，未能造成伤害',
    // 大厅关卡卡片 —— 显示上一关。
    'lobby_previous_stage': '上一关',
    'shop_per_hero': '每个',
    // 英雄HUD标签 —— 按元素的技能，每种属性各一个。
    'battle_hero_skill_fire_a': '焚尽',
    'battle_hero_skill_water_a': '潮汐打击',
    'battle_hero_skill_grass_a': '绽放',
    'battle_hero_skill_light_a': '爆裂',
    'battle_hero_skill_poison_a': '剧毒爆发',
    // 没有技能的英雄的战斗说明（与详情对话框的语句键区分）。
    'battle_skill_none': '无技能',
    // 技能说明弹窗底部 —— 使用次数提示。
    'battle_skill_once': '每关1次',

    // 结果
    'result_victory': '🎉 胜利！',
    'result_defeat': '💀 失败',
    'result_clear': '第 {n} 关通关！',
    'result_defeated': '在第 {n} 关失败。',
    'result_game_win': '获得游戏货币',
    'result_game_loss': '游戏货币 (失败无奖励)',
    'result_attack': '⚔ 攻击力 {n}',
    'result_damage_analysis': '战斗伤害分析',
    'result_damage_dealt': '造成的伤害',
    'result_damage_received': '受到的伤害',
    'result_largest_hit': '最大单次打击',
    'result_damage_sources': '按伤害来源 (次数 × 合计)',
    'result_incoming_breakdowns': '受击计算明细',
    'result_party_stat_breakdown': '各英雄最终属性',
    'result_stat_breakdown_legend': '英雄个人攻击力会加算到该颜色符文伤害 · DEF 越高怪物反击越低',
    'damage_source_runeMatch': '符文连消',
    'damage_source_heroSkill': '英雄技能',
    'damage_source_poisonTick': '中毒层数',
    'damage_source_blackRune': '黑色符文受击',
    'damage_source_monsterAttack': '怪物攻击',
    'damage_source_bossUltimate': '首领终极技',
    'damage_total': '连消合计',
    'damage_overflow': '+{n}次 · {d}',
    'result_btn_next': '下一关 ▶',
    'result_btn_retry': '再次挑战 (Play {n})',
    'result_btn_shop': '前往商店 (成长后再战)',
    'result_btn_lobby': '前往大厅',

    // 教程
    'tutorial_title': '🎓 教程',
    'tutorial_skip': '跳过',
    'tutorial_help': '帮助',
    'tutorial_step': 'STEP {current} / {total}',
    'tutorial_step_tag': 'STEP {current} · {id}',
    'tutorial_hint': '💡 提示: 滑动 {from} ⇄ {to}',
    'tutorial_tile_label': '(第{col}列, 第{row}行)',
    'tutorial_skill_tap': '点击英雄头像使用技能',
    // Fire/Light 是指标型技能 —— 点击头像后还需选择目标。
    'tutorial_skill_tap_target': '点击头像后，再点击棋盘上的符文进行瞄准',
    'tutorial_skip_dialog_title': '跳过教程',
    'tutorial_skip_dialog_msg': '可能会错过部分教学内容。\n确定要跳过吗？',
    'tutorial_continue': '继续',
    'tutorial_title_match': '连消3枚相同符文',
    'tutorial_msg_match':
        '棋盘上有🔥火焰符文竖排在一起。\n'
        '滑动一枚符文与相邻符文交换，连消3枚攻击怪物！',
    'tutorial_title_affinity': '瞄准怪物弱点',
    'tutorial_msg_affinity':
        '伤害 = “该属性存活英雄攻击力之和” × 连击 × 属性克制。\n'
        '该怪物弱🔥火焰，因此受到 ×1.5。连消3枚火焰符文吧。',
    'tutorial_title_combo': '连锁就会产生连击！',
    'tutorial_msg_combo':
        '连消后符文下落再次凑齐3枚即为 COMBO！\n'
        '每次连击伤害 +20%。保留棋盘上方的 GGG 再滑动。',
    'tutorial_title_monster': '回合结束时怪物会攻击',
    'tutorial_msg_monster':
        '滑动一次后回合结束，怪物就会攻击。\n'
        '注意队伍HP(🛡 队伍)会减少。',
    'tutorial_title_black-danger': '🖤 黑色符文很危险',
    'tutorial_msg_black-danger':
        '连消3枚以上黑色符文，队伍会受到伤害！\n'
        '棋盘上有3枚相邻的黑色符文。滑动会受伤……请小心。',
    'tutorial_title_black-4-line': '黑色4枚: 受伤 + 同列净化！',
    'tutorial_msg_black-4-line':
        '连消4枚黑色符文时，队伍会受伤，且同列其余黑色符文也会被净化。\n'
        '棋盘上有4枚黑色 + 1枚将被净化。滑动看看吧。',
    'tutorial_title_black-purge': '凑齐5枚黑色符文即可净化！',
    'tutorial_msg_black-purge':
        '将5枚黑色符文连成一线，可在不受伤害的情况下净化棋盘上所有黑色符文。\n'
        '下方棋盘已有5枚黑色符文。不要碰它们，滑动其他符文。',
    'tutorial_title_skill': '使用英雄技能',
    'tutorial_msg_skill':
        '点击英雄头像即可发动该英雄的技能。\n'
        '每个英雄每关可使用1次。每个玩家回合全队只能使用1次，使用后怪物会反击。',
    'tutorial_title_boss': '最后！击败首领',
    'tutorial_msg_boss':
        '连消🔥火焰3枚击败首领即可完成教程！\n'
        '战斗胜利可获得游戏货币奖励并进入下一关。',

    // 初次战败·同伴招募向导
    'guide_name': '向导',
    'guide_first_defeat_msg':
        '你是因为同伴不足才失败的。\n'
        '我来帮你——用这个招募一名同伴吧。',
    'guide_first_defeat_cta': '去招募同伴',
    'guide_first_defeat_cancel': '稍后再说',
    'guide_shop_banner': '点击下方单抽，招募一名新同伴！',
    'guide_pull_done_msg':
        '现在你有了并肩作战的同伴。\n'
        '要再挑战一次吗？',
    'guide_pull_done_cta': '前往大厅再战',

    // 元素名 (RuneElement.name → 翻译)
    'element_fire': '火',
    'element_grass': '草',
    'element_water': '水',
    'element_light': '闪电',
    'element_poison': '毒',
    'element_black': '黑色',
  };

  // ─────────────────────────────────────────────────────────────
  // 繁體中文 (zh-Hant, 台灣用語)
  // ─────────────────────────────────────────────────────────────
  static const Map<String, String> _zhHant = {
    // 通用
    'common_cancel': '取消',
    'common_retry': '重試',
    'currency_game': '⚡ {n}',
    'currency_play': '🎟 {n}',
    'currency_hero': '⭐ {n}',
    'common_stage': 'STAGE {n}',

    // 標題畫面
    'title_subtitle': '符文拼圖戰術',
    'title_start': '開始戰鬥',

    // 底部導覽
    'nav_lobby': '大廳',
    'nav_party': '隊伍',
    'nav_shop': '商店',
    'nav_settings': '設定',

    // 主大廳
    'main_load_error': '無法讀取存檔資料。',
    'main_reset_done': '進度已重置。',
    'exit_confirm': '再按一次返回鍵退出',

    // 大廳
    'lobby_mode_title': '🧩 RUNE 模式',
    'lobby_best_clear': '最高通關',
    'lobby_record': '戰績',
    'lobby_record_value': '{wins}勝 {losses}負',
    'lobby_battle_start': '開始戰鬥 (STAGE {n})',
    'entry_cost_label': '入場費用: 🎟 {n}',
    'entry_error_no_play': 'Play貨幣不足。(需要 {n} 🎟)',
    'entry_short_title': 'Play貨幣不足',
    'entry_short_watch_ad': '觀看廣告 (+{n} 🎟)',
    'entry_short_go_shop': '前往商店',
    'daily_reward_title': '🎁 每日獎勵',
    'daily_reward_desc': '🎟 +{play} · ⭐ +{hero} (每日1次)',
    'daily_reward_claim': '領取',
    'daily_reward_claimed': '今日已領取',
    'ad_reward_play': '▶ 觀看廣告: +{n} 🎟',
    'ad_reward_hero': '▶ 觀看廣告: +{n} ⭐',
    'ad_load_failed': '無法載入廣告，請稍後再試。',
    'ad_play_owned': '你已擁有Play券。',
    'ad_hero_daily_done': '英雄廣告獎勵明天可再次領取。',
    'ad_reward_granted': '已獲得 +{n} 獎勵！',
    'lobby_view_upgrades': '查看永久強化',
    'party_summary': '目前隊伍',
    'hero_owned': '已擁有 {n}',

    // 屬性人數顯示（不含倍率 —— 攻擊力之和即為傷害基數）
    'party_count_unit': '{n}',

    // 隊伍
    'party_title': '👥 隊伍管理',
    'party_counter': '隊伍 {total} / {max}',
    'party_desc':
        '符文連消的傷害等於「該屬性存活英雄的攻擊力之和」×連擊×屬性克制。'
        '因此同屬性的英雄越多，該顏色的傷害就越高。',
    'party_recruit_hint': '💡 可在商店分頁中使用英雄貨幣(⭐)招募英雄。',
    'party_unassign_tooltip': '從隊伍中移除',
    'party_assign_tooltip': '加入隊伍',
    'party_assign_confirm_title': '英雄加入',
    'party_assign_confirm_message': '要將 {hero} 加入隊伍嗎？',
    'party_assign_yes': '是',
    'party_assign_no': '否',
    'party_in_party': '已編入',
    'party_tab_all': '隊伍',
    'party_empty_hint': '還沒有擁有英雄。請到商店分頁招募。',
    'party_slot_add_tooltip': '點擊編入英雄',
    'party_slots_full': '隊伍已滿 (5/5)',
    'party_synergy_none': '隊伍中沒有英雄',
    'party_picker_title': '選擇英雄',
    'party_picker_counter': '隊伍 {total} / {max}',
    'party_picker_assigned': '已編入',
    'party_picker_empty': '沒有可編入的英雄。請到商店招募。',
    'party_picker_hint': '點擊英雄即可將其加入隊伍。',
    'party_unassign_confirm_title': '從隊伍中移除',
    'party_unassign_confirm_message': '要將 {hero} 從隊伍中移除嗎？',
    'hero_name_fire_a': '恩伯',
    'hero_name_grass_a': '莉安娜',
    'hero_name_water_a': '瑪麗斯',
    'hero_name_light_a': '露米婭',
    'hero_name_poison_a': '尼克斯',

    // 英雄詳情彈窗 / 英雄圖鑑
    'hero_detail_desc_label': '描述',
    'hero_detail_skill_label': '英雄技能',
    'hero_skill_none': '該英雄沒有技能。',
    // 各英雄技能詳情 —— 依元素區分技能（每種屬性1個技能，每種屬性1名英雄）。
    'hero_skill_fire_a': '每關1次：選擇一枚符文，棋盤上所有該顏色的符文都會變為火焰符文。',
    'hero_skill_water_a': '每關1次：棋盤上每有一枚水符文，造成10點直接傷害。',
    'hero_skill_grass_a': '每關1次：棋盤上每有一枚草符文，為隊伍恢復10點HP。',
    'hero_skill_light_a': '每關1次：選擇任意一枚符文，其周圍3×3區域爆炸，其餘符文下落。',
    'hero_skill_poison_a': '每關1次：燒盡棋盤上所有毒符文，每清除一枚造成10點傷害。其餘符文下落。',
    'hero_state_not_owned': '未擁有',
    'hero_detail_starter': '初始(免費)',
    'hero_detail_stats_label': '基礎屬性',
    'stat_hp': 'HP',
    'stat_atk': 'ATK',
    'stat_def': 'DEF',
    'hero_detail_open': '詳情',
    'hero_level_label': '等級',
    'hero_level_bonus': '等級加成',
    'hero_level_max': 'MAX',
    'hero_exp_progress': '{exp} / {next} EXP',
    'result_level_up_title': '⬆ 升級',
    'result_level_up_line': 'Lv.{from} → Lv.{to}',
    'result_hero_exp_title': '英雄成長',
    'result_hero_exp_gain': '+{n} EXP',

    // 稀有度說明為輔助資訊，UI 以星數顯示。
    'rarity_r': '普通',
    'rarity_sr': '稀有',
    'rarity_ssr': '史詩',
    'rarity_ur': '傳說',

    // 英雄招募（抽卡）
    'gacha_header': '英雄招募 (英雄貨幣 ⭐)',
    'gacha_single': '1連抽',
    'gacha_ten': '10連抽',
    'gacha_cost': '⭐{n}',
    'gacha_rates_header': '機率',
    'gacha_rates_note': '更高稀有度隨關卡推進解鎖。重複英雄會被你已擁有的最高稀有度英雄吸收。',
    'gacha_codex_progress': '已擁有英雄 {owned} / {total}',
    'gacha_badge_new': '新',
    'gacha_badge_promote': '升階',
    'gacha_badge_levelup': '升級',
    'gacha_badge_max': '最高階',
    'gacha_promote_to': '{from} → {to}',
    'gacha_confirm': '確認',
    'gacha_error_hero': '英雄貨幣不足。(需要 {n} ⭐)',
    'gacha_error_hero_count': '英雄貨幣不足。({count}連需要 {n} ⭐)',
    'gacha_empty_pool': '暫無可招募的英雄。',
    'hero_codex_title': '📖 英雄圖鑑',
    'hero_codex_desc': '共有5名英雄。點擊任意英雄即可查看其描述與技能。',
    'hero_desc_fire_a': '最初的火焰英雄。她操縱燃燒的符文如同呼吸一般自然，是最擅長操控爆炸寶珠的人。',
    'hero_desc_grass_a': '在任何人開口之前就讀懂隊伍體力的治療者。她用草之力靜靜填補被火焰燒灼的痕跡。',
    'hero_desc_water_a': '表面平靜、底下卻深不見底的水流。洗去棋盤上的黑色殘渣，是她的職責。',
    'hero_desc_light_a': '尚未學會自己的光為何而亮的明亮靈魂。即便如此，她仍站在隊伍最前方守住陣線。',
    'hero_desc_poison_a': '徒手操控劇毒，隊伍的生命卻幾乎不為所動。這是踏入艱險之路的第一步。',

    // 商店
    'shop_title': '🛒 商店',
    'shop_upgrades_header': '隊伍屬性魔導書與強化',
    'shop_owned_badge': '已擁有',
    'shop_locked_unlock': '第 {n} 關解鎖',
    'shop_error_max_level': '已達到最高等級。',
    'shop_error_game': '遊戲貨幣不足。(需要 {n} ⚡)',
    'shop_effect': '效果: {label}',
    'shop_max_level': '最高等級',
    'shop_buy': '購買 ({n} ⚡)',
    'shop_lv': 'Lv. {level} / {max}',
    'book_level': 'Lv. {level}',
    'book_purchase_success': '魔導書強化完成！隊伍屬性得到提升。',
    'book_name_hp': '生命之書',
    'book_name_atk': '鬥志之書',
    'book_name_def': '守護之書',
    'book_name_affinity_bonus': '破裂之書',
    'book_name_affinity_resistance': '結界之書',
    'book_stat_hp': '隊伍HP',
    'book_stat_atk': '隊伍ATK',
    'book_stat_def': '隊伍DEF',

    // 升級
    'upgrade_name_partyAttack': '隊伍攻擊力',
    'upgrade_name_partyMaxHp': '隊伍最大HP',
    'upgrade_name_gameGain': '遊戲貨幣獲取',
    'upgrade_desc_partyAttack': '戰鬥基礎攻擊力(Party Base Attack)每級 +10。',
    'upgrade_desc_partyMaxHp': '隊伍最大HP每級 +10。',
    'upgrade_desc_gameGain': '勝利時獲取的遊戲貨幣每級 +10%。',
    'upgrade_effect_partyAttack': '攻擊力',
    'upgrade_effect_partyMaxHp': '最大HP',
    'upgrade_effect_gameGain': '遊戲貨幣獲取',

    // 設定
    'settings_title': '⚙ 設定',
    'settings_section_tutorial': '教學',
    'settings_replay_tutorial': '重看教學',
    'settings_audio': '音訊',
    'settings_music': '背景音樂',
    'settings_sound_effects': '音效',
    'settings_section_data': '資料',
    'settings_reset_progress': '重置進度',
    'settings_language': '語言',
    'settings_language_select': '選擇語言',
    'settings_language_current': '目前語言: {name}',
    'settings_reset_dialog_title': '重置進度',
    'settings_reset_dialog_msg': '所有貨幣/通關/強化/隊伍都將被刪除。\n繼續嗎？',
    'settings_reset_confirm': '重置',
    'settings_footer':
        'Rune Puzzle Tactics v0.8\n本機存檔(SQLite) · Firebase Analytics 已就緒',

    // 應用程式資訊
    'common_close': '關閉',
    'settings_section_about': '關於',
    'settings_credits': '製作人員',
    'settings_rate_app': '評價應用程式',
    'settings_other_apps': '瀏覽其他應用程式',
    'settings_coming_soon': '敬請期待',
    'credits_title': '製作人員',
    'credits_version': '版本 {version}',
    'credits_role_dev': '開發與設計 — Rune Puzzle Tactics 團隊',
    'credits_role_art': '美術 — 像素與卡牌圖片包',
    'credits_role_sound': '音效 — BFXR 音效包',
    'credits_role_thanks': '感謝遊玩！',

    // 上次遊玩的關卡
    'lobby_last_played': '上次遊玩',
    'lobby_last_result_win': '通關成功',
    'lobby_last_result_lose': '失敗 — 再挑戰一次',

    // 隊伍 `+` 不可用時的說明
    'party_slots_nothing_to_add': '已編入全部擁有的英雄',

    // 英雄圖鑑網格
    'codex_owned_count': '已擁有 {owned} / {total}',

    // 英雄招募保底
    'gacha_pity_progress': '再抽 {n} 次單抽必得新英雄',
    'gacha_pity_counter': '連續重複 {count} / {max}',
    'gacha_pity_ready': '保底就緒 — 下次單抽必為新英雄',
    'gacha_pity_note': '重複次數越多累積越高。10連抽不受影響。',
    'gacha_skip': '跳過',
    'gacha_congrats_new': '新英雄登場！',
    'gacha_ten_no_new': '這次沒有新英雄',

    // 語言選擇對話框
    'lang_dialog_title': '選擇語言',
    'lang_en': 'English',
    'lang_ko': '한국어',
    'lang_ja': '日本語',
    'lang_zh_hans': '简体中文',
    'lang_zh_hant': '繁體中文',

    // 戰鬥
    'battle_leave_tooltip': '退出',
    'battle_type_boss': '首領',
    'battle_boss_ultimate_warning': '⚠ 下一擊是終極技！',
    'battle_type_elite': '菁英',
    'battle_type_normal': '普通',
    'battle_pause_tooltip': '暫停',
    'turn_monster': '⚠ 怪物回合',
    'turn_victory': '🏆 勝利',
    'turn_defeat': '💀 失敗',
    'turn_retreat': '退出',
    'turn_player': '▶ 玩家回合',
    'hp_party': '🛡 隊伍',
    'hp_monster': '👹 怪物',
    'combo': 'COMBO x{n}',
    'battle_paused': '已暫停',
    'battle_resume': '繼續',
    'battle_restart': '重新開始',
    'battle_go_lobby': '前往大廳',
    'battle_ready_go': 'Ready... GO!',

    // 關卡準備（進入前確認）
    'stage_prep_title': '關卡準備',
    'stage_prep_monster_count': '怪物 {n}隻',
    'stage_prep_party': '出戰隊伍',
    'stage_prep_confirm': '開始戰鬥',
    'stage_prep_play_held': '/ 持有 {n}',
    'stage_prep_info_body':
        '怪物無屬性，但每個關卡都有弱點(×1.5)屬性與劣勢(×0.5)屬性。'
        '符文連消的傷害等於「該屬性存活英雄攻擊力之和」×連擊×屬性克制。\n'
        '點擊空位(+)可編入英雄。點擊英雄頭像即可使用技能。每個英雄每關可使用1次，'
        '且每個玩家回合全隊只能使用1次。',
    'incoming_damage_formula':
        'ATK {atk} × 100 / (100 + DEF {def}) = -{damage}; '
        'HP {hpBefore}→{hpAfter}/{hpMax}',

    // 怪物屬性克制（怪物無屬性 —— 弱點/劣勢以目前登場怪物為準）
    'battle_monster_weak': '弱點',
    'battle_monster_resist': '劣勢',
    // 波次戰鬥 —— 怪物依序登場（目前 i / 共 n）。
    'battle_monster_wave': '怪物 {i}/{n}',

    // 波次獎勵 —— 擊敗怪物後隊伍HP恢復 + 技能充能(1名)
    'wave_reward_title': '擊敗怪物！',
    'wave_reward_heal': '隊伍HP +{n} 恢復',
    'wave_reward_skill': '技能充能 (1名)',
    'wave_reward_skip': '跳過',

    // 大廳關卡卡片 / 隊伍摘要
    'lobby_stage_progress': '最高進入 {cleared}',
    'lobby_max_stage_banner': '已到達最終關卡！可以重新挑戰。',
    'lobby_current_party': '出戰隊伍',
    'lobby_party_stats': '英雄屬性',
    'lobby_party_defense': '隊伍DEF',
    'lobby_upgrade_levels': '永久強化',

    // 英雄技能
    'battle_skill_used': '已使用',
    // 標記型技能(Fire/Light)正在選擇棋盤目標格。
    'battle_skill_aiming': '瞄準',
    // 倒下的英雄（頭像下方HP 0 → ✕ 覆蓋層）
    'battle_hero_down': '倒下',
    // 連消成功但隊伍中沒有該屬性英雄，傷害為0時的怪物中央警告。
    'battle_no_element_hero': '隊伍中沒有該屬性英雄，未能造成傷害',
    // 大廳關卡卡片 —— 顯示上一關。
    'lobby_previous_stage': '上一關',
    'shop_per_hero': '每個',
    // 英雄HUD標籤 —— 依元素的技能，每種屬性各一個。
    'battle_hero_skill_fire_a': '焚盡',
    'battle_hero_skill_water_a': '潮汐打擊',
    'battle_hero_skill_grass_a': '綻放',
    'battle_hero_skill_light_a': '爆裂',
    'battle_hero_skill_poison_a': '劇毒爆發',
    // 沒有技能的英雄的戰鬥說明（與詳情對話框的語句鍵區分）。
    'battle_skill_none': '無技能',
    // 技能說明彈窗底部 —— 使用次數提示。
    'battle_skill_once': '每關1次',

    // 結果
    'result_victory': '🎉 勝利！',
    'result_defeat': '💀 失敗',
    'result_clear': '第 {n} 關通關！',
    'result_defeated': '在第 {n} 關失敗。',
    'result_game_win': '獲得遊戲貨幣',
    'result_game_loss': '遊戲貨幣 (失敗無獎勵)',
    'result_attack': '⚔ 攻擊力 {n}',
    'result_damage_analysis': '戰鬥傷害分析',
    'result_damage_dealt': '造成的傷害',
    'result_damage_received': '受到的傷害',
    'result_largest_hit': '最大單次打擊',
    'result_damage_sources': '依傷害來源 (次數 × 合計)',
    'result_incoming_breakdowns': '受擊計算明細',
    'result_party_stat_breakdown': '各英雄最終屬性',
    'result_stat_breakdown_legend': '英雄個人攻擊力會加算到該顏色符文傷害 · DEF 越高怪物反擊越低',
    'damage_source_runeMatch': '符文連消',
    'damage_source_heroSkill': '英雄技能',
    'damage_source_poisonTick': '中毒層數',
    'damage_source_blackRune': '黑色符文受擊',
    'damage_source_monsterAttack': '怪物攻擊',
    'damage_source_bossUltimate': '首領終極技',
    'damage_total': '連消合計',
    'damage_overflow': '+{n}次 · {d}',
    'result_btn_next': '下一關 ▶',
    'result_btn_retry': '再次挑戰 (Play {n})',
    'result_btn_shop': '前往商店 (成長後再戰)',
    'result_btn_lobby': '前往大廳',

    // 教學
    'tutorial_title': '🎓 教學',
    'tutorial_skip': '跳過',
    'tutorial_help': '幫助',
    'tutorial_step': 'STEP {current} / {total}',
    'tutorial_step_tag': 'STEP {current} · {id}',
    'tutorial_hint': '💡 提示: 滑動 {from} ⇄ {to}',
    'tutorial_tile_label': '(第{col}列, 第{row}行)',
    'tutorial_skill_tap': '點擊英雄頭像使用技能',
    // Fire/Light 是指標型技能 —— 點擊頭像後還需選擇目標。
    'tutorial_skill_tap_target': '點擊頭像後，再點擊棋盤上的符文進行瞄準',
    'tutorial_skip_dialog_title': '跳過教學',
    'tutorial_skip_dialog_msg': '可能會錯過部分教學內容。\n確定要跳過嗎？',
    'tutorial_continue': '繼續',
    'tutorial_title_match': '連消3枚相同符文',
    'tutorial_msg_match':
        '棋盤上有🔥火焰符文直排在一起。\n'
        '滑動一枚符文與相鄰符文交換，連消3枚攻擊怪物！',
    'tutorial_title_affinity': '瞄準怪物弱點',
    'tutorial_msg_affinity':
        '傷害 = 「該屬性存活英雄攻擊力之和」 × 連擊 × 屬性克制。\n'
        '該怪物弱🔥火焰，因此受到 ×1.5。連消3枚火焰符文吧。',
    'tutorial_title_combo': '連鎖就會產生連擊！',
    'tutorial_msg_combo':
        '連消後符文下落再次湊齊3枚即為 COMBO！\n'
        '每次連擊傷害 +20%。保留棋盤上方的 GGG 再滑動。',
    'tutorial_title_monster': '回合結束時怪物會攻擊',
    'tutorial_msg_monster':
        '滑動一次後回合結束，怪物就會攻擊。\n'
        '注意隊伍HP(🛡 隊伍)會減少。',
    'tutorial_title_black-danger': '🖤 黑色符文很危險',
    'tutorial_msg_black-danger':
        '連消3枚以上黑色符文，隊伍會受到傷害！\n'
        '棋盤上有3枚相鄰的黑色符文。滑動會受傷……請小心。',
    'tutorial_title_black-4-line': '黑色4枚: 受傷 + 同列淨化！',
    'tutorial_msg_black-4-line':
        '連消4枚黑色符文時，隊伍會受傷，且同列其餘黑色符文也會被淨化。\n'
        '棋盤上有4枚黑色 + 1枚將被淨化。滑動看看吧。',
    'tutorial_title_black-purge': '湊齊5枚黑色符文即可淨化！',
    'tutorial_msg_black-purge':
        '將5枚黑色符文連成一線，可在不受傷害的情況下淨化棋盤上所有黑色符文。\n'
        '下方棋盤已有5枚黑色符文。不要碰它們，滑動其他符文。',
    'tutorial_title_skill': '使用英雄技能',
    'tutorial_msg_skill':
        '點擊英雄頭像即可發動該英雄的技能。\n'
        '每個英雄每關可使用1次。每個玩家回合全隊只能使用1次，使用後怪物會反擊。',
    'tutorial_title_boss': '最後！擊敗首領',
    'tutorial_msg_boss':
        '連消🔥火焰3枚擊敗首領即可完成教學！\n'
        '戰鬥勝利可獲得遊戲貨幣獎勵並進入下一關。',

    // 初次戰敗·同伴招募嚮導
    'guide_name': '嚮導',
    'guide_first_defeat_msg':
        '你是因為同伴不足才失敗的。\n'
        '我來幫你——用這個招募一名同伴吧。',
    'guide_first_defeat_cta': '去招募同伴',
    'guide_first_defeat_cancel': '稍後再說',
    'guide_shop_banner': '點擊下方單抽，招募一名新同伴！',
    'guide_pull_done_msg':
        '現在你有了並肩作戰的同伴。\n'
        '要再挑戰一次嗎？',
    'guide_pull_done_cta': '前往大廳再戰',

    // 元素名 (RuneElement.name → 翻譯)
    'element_fire': '火',
    'element_grass': '草',
    'element_water': '水',
    'element_light': '閃電',
    'element_poison': '毒',
    'element_black': '黑色',
  };
}
