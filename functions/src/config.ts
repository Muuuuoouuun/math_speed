export const APP_REGION = 'asia-northeast3';
export const ACTIVE_SEASON_ID = '2026_s1';
export const BALANCE_VERSION = 'game_balance_v2';
export const ELIGIBILITY_ATTEMPTS = 3;
export const SESSION_TTL_MINUTES = 10;
export const LEADERBOARD_LIMIT = 100;
// 한 라운드에서 받을 수 있는 최대 답안 수 (가장 쉬운 모드 기준으로도 충분히 넉넉한 값)
export const MAX_ANSWERS_PER_ROUND = 400;
// 클라이언트 타이머 틱(100ms)과 문제별 최소 시간 보정을 흡수하는 여유 시간
export const TIMEOUT_GRACE_MS = 1500;
// 세션 발급 응답 + 라운드 종료 후 제출(1회 재시도 포함)까지 허용하는 네트워크 여유 시간
export const SUBMIT_LATENCY_SLACK_MS = 45000;
// 서버가 세션을 발급한 시각보다 라운드가 빨리 끝났다고 주장할 수 있는 허용 오차
export const CLOCK_SKEW_SLACK_MS = 3000;
