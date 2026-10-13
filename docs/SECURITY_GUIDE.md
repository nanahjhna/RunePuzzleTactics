# 보안 가이드 — API 키 관리 (RunePuzzleTactics)

> 대상: Flutter 앱(`lib/firebase_options.dart`, Firebase 콘솔)
> 작성일: 2026-09-21 (2026-09-22 갱신 — 광고(AdMob) 통합 제거 반영)

---

## 1. 현재 상태 요약

| 항목 | 위치 | 성격 | 처리 |
|---|---|---|---|
| Firebase API 키 | `lib/firebase_options.dart`, `android/app/google-services.json` | **공개 키** (클라이언트 내장) | 숨길 수 없음 → **제한(Restriction) + App Check** |
| 릴리스 서명 키 비밀번호 | `android/key.properties` | **진짜 비밀** | ✅ Git 미추적(gitignore) — 유지 |

> AdMob(광고) 통합은 Rune 전용 앱으로 정리하면서 **완전히 제거**되었다.
> AndroidManifest의 AdMob 메타데이터, `GADApplicationIdentifier`(iOS), 관련 의존성
> (`google_mobile_ads`), 광고 헬퍼/위젯 파일이 모두 삭제되었다.

**중요한 인식**: Firebase API 키는 *설계상* 앱 바이너리에 내장되는 공개 값입니다.
스토어에 올라간 APK/IPA를 열어보면 누구나 추출할 수 있으므로, "코드에서 지우기"만으로는
보안이 강화되지 않습니다. **실질적인 방어는 아래 2·3장(클라우드 콘솔 제한)에 있습니다.**

---

## 2. [필수] Firebase API 키 제한 (Google Cloud Console)

콘솔: https://console.cloud.google.com/apis/credentials
(프로젝트: `RunePuzzleTactics-dcb7c`)

1. **Android 키** (`AIzaSyAqlh…`)
   - 애플리케이션 제한 → **Android 앱**
   - 패키지명: `com.han.RunePuzzleTactics`
   - SHA-1 지문: 아래 명령으로 확인 후 등록
     ```
     keytool -list -v -keystore <keystore 경로> -alias upload
     ```
     (또는 `cd android && ./gradlew signingReport`)
2. **iOS/macOS 키** (`AIzaSyB9oI…`)
   - 애플리케이션 제한 → **iOS 앱**
   - 번들 ID: `com.han.RunePuzzleTactics`
3. **Web 키 2개** (`AIzaSyDqb0…` — web/windows 공용)
   - 애플리케이션 제한 → **HTTP 리퍼러(referrer)**
   - 허용 목록 예: `http://localhost:*`, `https://<호스팅 도메인>/*`
4. 각 키에서 **사용하지 않는 API** 제한 가능 (예: 이 앱은 Maps 등 미사용)

---

## 3. [필수] Firebase App Check + 보안 규칙

- **App Check** (콘솔: Firebase → Build → App Check)
  - Android: **Play Integrity** 등록
  - iOS/macOS: **App Attest** 등록
  - Web: **reCAPTCHA v3** 등록
  - 적용 대상: Authentication, Firestore, Storage 등 사용 서비스 전체
  - 효과: 추출된 키로 위장한 무단 클라이언트의 접근 차단
- **보안 규칙** (Firestore/Storage)
  - 현재 로컬 SharedPreferences 저장이 중심이라 영향은 작지만, Firebase 백엔드를 쓴다면
    꼭 "인증된 사용자에게만 접근" 등 최소 권한 규칙으로 검토한다.
  - 테스트 규칙(`allow read, write: if true`)이 배포에 포함되지 않게 한다.

---

## 4. 키가 이미 외부에 공개되었다면 (키 회전)

비공개 저장소만 사용했다면 회전은 불필요. 공개 저장소/이슈 등에 노출된 적이 있다면:

1. Firebase 콘솔 → 프로젝트 설정 → **API 키 재생성** 후 2장의 제한 재적용
2. Android 서명 키(keystore)는 절대 회전 불가 — 유출 시 Play Console에서 업로드 키 교체 절차 진행

---

## 5. 관리 정책 체크리스트

- [ ] 2장: 모든 Firebase API 키에 패키지/번들/리퍼러 제한 적용
- [ ] 3장: App Check 활성화 + 보안 규칙 최소 권한
- [ ] `git config core.hooksPath .githooks` 활성화 상태 유지
- [ ] `android/key.properties`가 Git에 추적/커밋된 적 없는지 주기적 확인