# Phase 1 Architecture

## 핵심 원칙

- 체감 속도는 클라이언트 로컬에서 확보한다.
- 공식 점수와 랭킹 반영은 서버가 권위를 가진다.
- 리더보드는 실시간 집계 문서와 배치 스냅샷을 분리한다.
- 1인 운영을 위해 가능한 한 Cloud Functions + Firestore로 유지하고, BigQuery는 재계산과 분석에만 사용한다.

## 실시간 경로

1. Flutter가 `createRankedSession({ mode })` 호출
2. 서버가 `sessionId`, `seed`, `expiresAt` 발급 (`issuedAt` 저장)
3. 앱이 같은 seed와 모드로 문제를 하나씩 생성 (타임어택: 정답마다 보너스 시간)
4. 유저가 손글씨 입력 → ML Kit이 온디바이스로 인식
5. 시간이 다 되면 앱이 문제별 `{ text, elapsedMs, strokeCount, pointCount, inkHash }`를 `submitRankedSession`에 자동 제출
6. 서버가 같은 seed로 문제를 재생성하고, 문제별 소요 시간으로 타이머를 **재생**해 시간 초과 이후 답안은 버림
7. 공식 점수 확정 후 `user_season_bests`, `aggregates` 갱신

## 서버 검증 규칙

- 문제별 소요 시간은 250ms ~ 99,999ms로 고정, 라운드당 최대 400개 답안
- 재생된 라운드 길이(사용 시간 + 남은 시간)와 실제 경과 시간(`issuedAt` → 제출)을 비교
  - 실제보다 빨리 끝났다고 주장(`finished_faster_than_clock`) 또는 보고보다 훨씬 오래 걸림(`round_longer_than_reported`) → `flagged: true`
  - flagged 기록은 `attempts`에 남지만 랭킹/시즌 최고에는 반영하지 않음 (BigQuery 분석용)
- 문제 생성·정답 정규화·점수 계산은 `shared/engine_golden.json` 벡터로 클라이언트와 서버 일치를 테스트

## 집계 문서

- `aggregates/{season_scope_entity_bucket}` (bucket = 모드 id 또는 `all`):
  - `eligibleUsers`
  - `sumBestBrainScore`
  - `avgBestBrainScore`
  - `attemptCount`

## BigQuery 역할

- 학교/지역 리더보드 백필
- 시즌 종료 통계
- 부정행위 패턴 분석
- 비정상 제출 속도 및 device hash 기반 탐지
