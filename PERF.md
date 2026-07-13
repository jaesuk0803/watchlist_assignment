# PERF.md — 병목 분석 · 개선 · 재현 가능한 수치

## 0. 측정 방법 (재현 가능)

`MarketFeed.pump()` 로 **동일 seed(20260703)의 결정론적 tick 수열**을 A/B/C에 똑같이
흘려 비교합니다. baseline(A)과 개선본(B/C)은 **UI 전파 방식만 다르고** 나머지(데이터·
정합성·스토어·집계)는 완전히 동일하므로 차이는 전파 비용에서만 나옵니다.

```bash
flutter test test/perf_benchmark_test.dart          # A/B/C rebuild 범위·build 시간
flutter test test/aggregation_benchmark_test.dart   # 증분 vs 전체재계산 집계 비용
```

- **측정 지표**
  1. `rowBuilds` — 200프레임 동안 rebuild된 행(`QuoteRow.build`) 총 횟수. **seed 고정이라
     실행마다 동일(결정론적).** "rebuild 범위 축소"의 직접 지표.
  2. `builds/frame` — 프레임당 평균 rebuild 행 수.
  3. `elapsedMs` — 200프레임 build 루프의 벽시계 시간(머신 의존 → A 대비 상대값으로 해석).
- 뷰포트: 1000×3000(px)로 키워 한 화면에 더 많은 행이 보이게 함(ListView는 보이는 행만
  build하므로, 이 조건에서 baseline이 프레임당 rebuild하는 "보이는 행"이 ~55개).

> **baseline(before) 정의 — 과제가 제시한 "가장 순진한 형태" 3가지를 모두 반영**:
> 1. tick 배치마다 `setState()` 로 목록 전체 rebuild(dirty 무시)
> 2. 행에 `RepaintBoundary` 없음
> 3. 요약값(시총 합계·Top-20)을 **매 프레임 전체 순회로 재계산**
>    (시총 O(n) 전체 합산, Top-20 O(n log n) 전체 정렬)
>
> B/C(개선본)는 1→행 단위 leaf 구독, 2→행별 RepaintBoundary, 3→증분 집계로 각각 대응합니다.
> 즉 A→B/C 비교는 이 세 축의 개선을 **동시에** 담습니다.

---

## 1. before/after 수치 (pump 200프레임, headless)

| 후보 | rowBuilds | builds/frame | elapsedMs | 비고 |
|---|---:|---:|---:|---|
| **A · setState (baseline)** | 11,000 | 55.0 | 2,325 | 전체 rebuild + RepaintBoundary 없음 + 요약 전체 재계산 |
| **B · ValueNotifier (채택)** | 716 | 3.6 | 500 | dirty 행만 rebuild + 행별 RepaintBoundary + 증분 집계 |
| **C · Riverpod** | 716 | 3.6 | 853 | B와 동일 범위, provider/ref 오버헤드로 build 시간 ↑ |

- **rebuild 범위**: B/C는 A 대비 **93.5% 감소** (11,000 → 716).
- **build 시간**: B는 A 대비 **약 4.7×** 빠름(2,325 → 500ms), C는 약 2.7×(→ 853ms).
- **B vs C**: rebuild 범위는 동일하나 **B가 build 시간에서 약 1.7× 우위**(500 vs 853ms).
  Riverpod의 provider 생성/ref 그래프 bookkeeping 비용이 고빈도 갱신 핫패스에서 드러남.

> 위 표의 `rowBuilds`/`builds/frame` 은 결정론적이라 재실행해도 동일합니다.
> `elapsedMs` 는 기기별로 달라지므로 절대값이 아니라 A 대비 비율로 보십시오.

### 1-1. 증분 집계 vs 전체 재계산 (요약 산출 비용)

위 표의 A elapsedMs에는 baseline이 요약을 매 프레임 전체 재계산하는 비용도 포함됩니다.
이 **집계 방식만 따로 떼어** 3,000회 요약 산출 비용을 비교하면(`aggregation_benchmark_test.dart`):

| 집계 방식 | 3,000회 요약 산출 | 갱신당 복잡도 |
|---|---:|---|
| **전체 재계산 (baseline A)** | 3,291 ms | 시총 O(n) + Top-20 O(n log n) |
| **증분 (채택 B/C)** | 5.7 ms | 시총 O(1) + Top-20 O(log n) 유지, 조회 O(20) |

→ 증분 집계가 **약 579× 빠름**. n=2,000·초당 수천 갱신 환경에서 전체 재계산은 프레임
예산을 금방 잠식하지만, 증분은 갱신량과 무관하게 값쌉니다. (이 수치도 seed 고정으로 재현 가능;
배율의 절대값은 기기별로 다를 수 있음)

---

## 2. 병목 분석 (baseline이 느린 이유)

1. **rebuild 범위 폭발** — 한 배치에 일부 종목만 바뀌어도 목록 전체를 rebuild. 보이는
   행 전부(≈55개)를 매 프레임 다시 빌드 → 11,000 builds.
2. **페인트 격리 없음** — `RepaintBoundary` 가 없어 한 행 변화가 인접 영역 재페인트로 번짐.
3. **요약/순위 전체 재계산 위험** — 순진하게 짜면 매 프레임 2,000종목을 재곱(시총)·재정렬
   (Top-20)하게 됨 → 프레임 예산 초과.

## 3. 적용한 개선

| 개선 | 내용 | 효과 |
|---|---|---|
| **dirty set** | 바뀐 종목코드만 모음 | 갱신 대상 최소화 |
| **프레임 coalescing** | `Ticker`(vsync)로 프레임당 1회 flush | 초당 수천 tick → 프레임당 1회 반영, 중복 rebuild 병합 |
| **leaf 단위 구독(B)** | 행별 `ValueNotifier` + `ValueListenableBuilder` | dirty 행만 rebuild (−93.5%) |
| **RepaintBoundary** | 행 단위 페인트 격리 | 변화가 인접 행 페인트로 번지지 않음 |
| **증분 시총** | 종목별 기여분 델타만 가감 | 갱신당 O(1) (전체 재곱 제거) |
| **증분 Top-20** | `SplayTreeSet` remove+insert | 갱신 O(log n), 조회 O(20) (전체 정렬 제거) |
| **검색 인덱스+debounce** | 시작 시 1회 구축, keystroke 200ms debounce | 매 tick/keystroke 전체 재계산 제거 |
| **itemExtent 고정** | 행 높이 고정 | 레이아웃 계산 단순화, 스크롤 성능 ↑ |

## 4. 성능 ↔ 신선도 트레이드오프 — 어디에 선을 그었나

- coalescing 단위 = **1프레임(≈16.6ms @60Hz)**.
- 60Hz에서 200ms ≈ 12프레임. 프레임당 flush면 **최대 stale ≈ 1프레임 ≪ 200ms** 로
  신선도 제약을 크게 만족하면서, 프레임당 작업량은 dirty 행으로 제한돼 60fps 유지.
- 더 세게 coalescing(예: 4~8프레임에 1회)하면 프레임은 더 여유롭지만 신선도가 나빠지고,
  프레임보다 자주 flush하면 같은 프레임에 여러 번 building만 늘 뿐 화면은 프레임당 한 번만
  갱신됨 → **프레임 단위가 최적점**이라 판단.

## 5. 실기기 프레임 타임 측정 절차 (권장)

헤드리스 벤치는 rebuild 범위/ build 시간을 결정론적으로 재현합니다. 실제 프레임 빌드/
래스터 시간은 아래로 확인하세요.

```bash
# baseline
flutter run --profile --dart-define=CANDIDATE=a
# 채택본
flutter run --profile --dart-define=CANDIDATE=b
```

DevTools → Performance 에서 스크롤/고빈도 갱신 중 **UI(build) / Raster** 시간을 비교합니다.
위젯 rebuild 횟수(`Rebuild Stats` · Track Widget Builds)는 **debug 모드에서만** 계측되므로,
rebuild 범위 근거는 위의 헤드리스 벤치(결정론적)로 제시하고, profile은 프레임 타임 확인에
씁니다.

### 관측: 플래그십 기기에서는 프레임 타임 차이가 작다 (정직한 한계)

실제 최신 아이폰(profile) + Impeller 로 목록을 빠르게 스크롤해도 **A/B 모두 프레임이
대부분 2~3ms** 로 60fps(16.6ms)에 큰 여유가 있었습니다. 이유:

- `ListView.builder` 가 **보이는 행(폰에서 ~12개)만** build → baseline이 "전체 rebuild"라도
  실제 재빌드량이 작음.
- 기기가 빨라 baseline의 낭비를 그냥 흡수함.

즉 **플래그십에서는 프레임 타임만으로 A/B 차이가 잘 드러나지 않습니다.** 그래서 개선의 근거는
(1) 결정론적 **rebuild 범위**(11,000→716, −93.5%)와 (2) **증분 집계 비용**(579×)으로 제시합니다.
이 낭비는 **저사양 기기·더 무거운 행·더 큰 뷰포트**에서 프레임 드랍으로 실제화되며, 플래그십에서도
CPU 사용/발열/배터리 측면의 이득으로 남습니다.
