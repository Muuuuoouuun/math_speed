# UI 디자인 시스템 — 종이와 연필

화면 전체를 "잘 정리된 연습장"으로 보이게 만드는 것이 목표입니다.
색과 여백을 한곳에서 관리해서, 화면이 늘어나도 톤이 흐트러지지 않게 합니다.

## 토큰

`app/lib/core/theme/app_tokens.dart` 하나가 기준입니다.

| 그룹 | 이름 | 쓰는 곳 |
| --- | --- | --- |
| 종이 | `paper` `paperDeep` `card` `cardSunk` | 배경, 카드, 눌린 면 |
| 흑연 | `ink` `graphite` `muted` `faint` | 본문 글자, 보조 글자 |
| 선 | `line` `lineSoft` `rule` `margin` | 테두리, 괘선, 공책 여백선 |
| 색연필 | `mint` `sky` `apricot` `lilac` `gold` `blush` | 난이도별 강조, 상태 표시 |

- `AppSpacing`: 4 / 8 / 12 / 16 / 22 / 28 / 40. 섹션 사이는 `xl`(28) 이상을 씁니다.
- `AppSpacing.gutter`(24): 모든 화면의 좌우 여백.
- `AppSpacing.maxContentWidth`(620): 태블릿에서 한 줄이 너무 길어지지 않게 잡는 상한.
- `AppRadius`: 12 / 16 / 22 / 28 / 34 / pill.
- `urgencyColor(ratio)`: 남은 시간 비율을 민트 → 살구 → 붉은 톤으로 변환합니다.

난이도별 강조색은 `AppPalette.crayons`에서 `GameMode.index`로 꺼내 씁니다.
그래서 난이도를 바꾸면 시작 버튼, 문제 카드, 연습장 안내선이 한 번에 같이 바뀝니다.

## 그림 요소

이미지 에셋 없이 전부 `CustomPainter`로 그립니다. 해상도에 상관없이 선이 또렷하고,
앱 용량도 늘지 않습니다.

- `PaperBackdrop` — 종이 그러데이션 + 모눈 점 + 섬유 얼룩 + 공책 여백선 + 가장자리 그늘.
  얼룩 좌표는 고정 시드라서 리빌드마다 튀지 않습니다.
- `PaperCard` — 실선 테두리 안쪽에 바느질 자국 점선을 한 겹 더 그린 패널.
  `accent`로 상단 색 띠, `tapeLabel`로 마스킹 테이프를 붙입니다.
- `PencilMascot` — 연필 캐릭터. `happy` / `cheer` / `sleepy` 세 가지 표정.
- `PencilRule` — 자로 대지 않고 그은 듯한 밑줄.
- `SparkleBurst` — 정답 때 문제 카드 위로 퍼지는 반짝임.
- `TimerGauge` — 눈금이 있는 아날로그 시계형 남은 시간 게이지.

## 화면 흐름

`GameSessionController.phase`가 화면을 결정합니다.

```
ready  →  (3-2-1 카운트다운)  →  playing  →  finished
  ↑                                              │
  └───────────────── 난이도 다시 고르기 ──────────┘
```

- **ready**: 마스코트 표지 → 난이도 카드 → 규칙 메모 → 시작 버튼.
  게임에 들어가기 전에 볼 것만 두고 나머지는 비웠습니다.
- **playing**: 시계 → 문제 → 연습장 → 정답 확인. 세부 지표는 여기서 빼고
  맞힌 문제 / 정확도 / 회복한 시간 세 가지만 아래에 둡니다.
- **finished**: 등급과 브레인 점수를 크게, 나머지 기록은 3열 타일로 정리합니다.

## 여백 규칙

1. 화면 좌우는 항상 `AppSpacing.gutter`.
2. 섹션과 섹션 사이는 `AppSpacing.xl`, 카드 안 요소 사이는 `sm`~`md`.
3. 시선이 먼저 닿아야 하는 요소(시계, 문제, 등급)는 위아래로 `lg` 이상 비웁니다.
4. 넓은 화면에서는 `maxContentWidth`로 폭을 묶고 남는 공간은 여백으로 둡니다.
