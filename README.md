# Brain Math

닌텐도식 두뇌 트레이닝 감성과 Firebase 서버리스 아키텍처를 결합한 모바일 수학 훈련 앱의 초기 구현입니다.

## 구조

- `app/`: Flutter 클라이언트 코드
- `functions/`: Firebase Cloud Functions 2nd gen
- `docs/`: 아키텍처 및 데이터 설계 문서
- `firestore.rules`: Firestore 보안 규칙
- `firestore.indexes.json`: Firestore 인덱스 정의

## 현재 포함된 범위

- 난이도 1~10 수학 문제 생성 엔진
- 속도/정확도/콤보 기반 브레인 점수 계산기
- 손글씨 입력 캔버스와 ML Kit 연동용 서비스 래퍼
- 랭크 세션 생성 / 제출 / 집계 갱신용 Cloud Functions 골격
- 학교/지역/전체 리더보드 집계 스키마

## 다음 실행 권장 순서

1. `app/`에서 Flutter 네이티브 셸 생성 및 Firebase 연결
2. `functions/`에서 의존성 설치 후 Emulator로 서버 로직 검증
3. FlutterFire 설정 파일과 ML Kit 모델 선다운로드 플로우 추가

## 참고

이 워크스페이스는 비어 있는 상태에서 시작했기 때문에, 현재 커밋은 "실행 가능한 설계 골격 + 핵심 도메인 로직"에 집중했습니다.

