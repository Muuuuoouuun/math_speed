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
