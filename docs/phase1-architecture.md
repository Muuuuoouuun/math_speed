# Phase 1 Architecture

## 핵심 원칙

- 체감 속도는 클라이언트 로컬에서 확보한다.
- 공식 점수와 랭킹 반영은 서버가 권위를 가진다.
- 리더보드는 실시간 집계 문서와 배치 스냅샷을 분리한다.
- 1인 운영을 위해 가능한 한 Cloud Functions + Firestore로 유지하고, BigQuery는 재계산과 분석에만 사용한다.

## 실시간 경로

1. Flutter가 `createRankedSession` 호출
2. 서버가 `sessionId`, `seed`, `expiresAt` 발급
3. 앱이 같은 seed로 문제 생성
4. 유저가 손글씨 입력
5. ML Kit이 온디바이스로 인식
6. 앱이 답안 요약을 `submitRankedSession`에 제출
7. 서버가 동일 seed로 재계산 후 공식 점수 확정
8. `user_season_bests`, `aggregates` 갱신

## 시간제 랭크전 V2

- `createTimeAttackSessionV2({mode})`는 4종 모드 중 하나와 시드, 만료 시각, 최대 답안 수, 최대 진행 시간을 반환한다.
- `submitTimeAttackSessionV2({sessionId, answers})`는 같은 문제를 재생성하고 시간 회복 규칙을 다시 실행해 점수를 확정한다.
- 10레벨 경로의 `mathEngine.ts` / `scoring.ts`와 시간제 `gameEngine.ts`는 각각 유지한다.
- 시간제 전체 집계는 `time-attack-all`, 모드별 집계는 `mode-{mode}`를 사용한다. 기존 10레벨 `all` / `level-{level}` 점수와 섞지 않는다.
- 시간제 최고점은 `timeAttackSeasonBest` / `timeAttackBestOverall`로 분리한다.
- 앱은 400답안 또는 9분에 종료하여 10분 세션 만료 전에 제출할 여유를 둔다.

## 집계 문서

- `aggregates/{season_scope_entity_level}`:
  - `eligibleUsers`
  - `sumBestBrainScore`
  - `avgBestBrainScore`
  - `attemptCount`

## BigQuery 역할

- 학교/지역 리더보드 백필
- 시즌 종료 통계
- 부정행위 패턴 분석
- 비정상 제출 속도 및 device hash 기반 탐지
