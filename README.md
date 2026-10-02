# Brain Math

닌텐도식 두뇌 트레이닝 감성과 Firebase 서버리스 아키텍처를 결합한 모바일 수학 훈련 앱입니다.

## 구조

- `app/`: Flutter 클라이언트 코드
- `functions/`: Firebase Cloud Functions 2nd gen
- `shared/engine_golden.json`: 클라이언트·서버 게임 엔진이 같은 결과를 내는지 검증하는 공용 테스트 벡터
- `docs/`: 아키텍처 및 데이터 설계 문서
- `firestore.rules`: Firestore 보안 규칙
- `firestore.indexes.json`: Firestore 인덱스 정의

## 현재 포함된 범위

- 4가지 모드(단순계산·사칙연산·두자리수·세자리수) 타임어택 — 정답마다 시간 회복
- 속도/정확도/콤보 기반 브레인 점수와 등급(거북이 ~ 치타)
- 손글씨 입력 캔버스 + ML Kit 온디바이스 인식 (숫자 후보 우선, 지우기 버튼, 수동 입력 대체)
- **랭크 모드**: 서버가 seed 발급 → 같은 seed로 문제 생성 → 라운드 종료 시 자동 제출 → 서버가 타이머를 재생해 공식 점수 확정
- 학교/지역 랭킹 패널 (15분 주기 스냅샷)

## 개발 명령

```bash
# 서버
cd functions
npm ci
npm run build
npm test          # 엔진 단위 테스트 + 공용 벡터 일치 확인
npm run golden    # 엔진 규칙을 의도적으로 바꾼 뒤 공용 벡터 재생성

# 앱
cd app
flutter pub get
flutter analyze
flutter test      # 공용 벡터 일치, 컨트롤러(연습/랭크 흐름), 위젯 스모크 테스트
```

> 문제 생성·정답 정규화·점수 계산 규칙은 `app/lib/features/game/domain/`과 `functions/src/gameEngine.ts`에 같은 로직으로 존재합니다.
> 한쪽을 바꾸면 반드시 다른 쪽도 바꾸고 `npm run golden`으로 벡터를 갱신하세요. 양쪽 테스트가 어긋남을 잡아냅니다.

## 다음 실행 권장 순서

1. `app/`에서 `flutter create --platforms=android,ios .`로 네이티브 셸 생성 후 `flutterfire configure`로 Firebase 연결
2. `functions/`에서 Emulator로 랭크 제출/집계 흐름 검증
3. ML Kit 모델 선다운로드 안내 UI 추가
