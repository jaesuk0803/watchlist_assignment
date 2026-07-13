# 실시간 관심종목 앱 (Edencrew Flutter 과제)

초당 최대 약 15,000건으로 갱신되는 2,000종목 목록을 60fps로 유지하는 실시간 관심종목
앱입니다. 정합성(지연·역순 tick / 거래정지 / 스트림 에러)과 성능(rebuild 범위 축소 ·
프레임 coalescing · 증분 집계)을 함께 다룹니다.

- 설계 결정과 근거: **[DESIGN.md](DESIGN.md)**
- 병목 분석 + 재현 가능한 before/after 수치: **[PERF.md](PERF.md)**

## 실행

```bash
flutter pub get

# 채택본(B · 행별 ValueNotifier) — 기본
flutter run --profile

# 후보 전환 (A: baseline / B: ValueNotifier / C: Riverpod)
flutter run --profile --dart-define=CANDIDATE=a
flutter run --profile --dart-define=CANDIDATE=b
flutter run --profile --dart-define=CANDIDATE=c
```

> 성능은 **반드시 profile/release** 로 확인하세요. debug는 실제보다 훨씬 느립니다.

## 검증

```bash
flutter analyze          # 0 issues
flutter test             # 회귀 테스트 + 벤치마크 (19 tests)
flutter test test/perf_benchmark_test.dart   # A/B/C 재현 가능한 벤치마크
```

`flutter test` 실행 시 벤치마크가 A/B/C의 rebuild 범위/시간을 표로 출력합니다(PERF.md).

## 화면

1. **관심종목 목록** — 요약(표시 종목 수·시총 합계) + 실시간 등락률 **Top-20** +
   **초성 검색**(예: `ㄱㅇ`→가온…) / 완성형(`전자`) / 코드(`000590`) + 2,000행 실시간 목록.
   거래정지 종목은 "정지" 배지 + 가격 회색 고정, 연결 불안정 시 상단 배너.
2. **종목 상세** — 현재가/등락폭·률, 시/고/저, 당일 거래량, 최근 체결가 스파크라인(실시간).
   상세가 떠 있는 동안 목록 갱신 비용은 멈춥니다.

## 구조 (feature-first + 실용적 Clean 4계층)

```
lib/
  seed/                         # 과제 제공(수정 금지): MarketFeed, 모델
  app/                          # 앱 셸 · 후보 선택(dart-define)
  features/stock/
    domain/                     # 엔티티 · repository 추상 (의존성 안쪽)
    data/                       # datasource(feed 단일 구독) · mapper · repository(정합성 경계)
    application/                # StockController(조율) · QuoteStore(SSOT+dirty)
                                #   services: 증분 시총 · Top-20 tracker · frame coalescer
                                #   search: 초성 유틸 · 검색 인덱스
    presentation/               # screens · widgets(공유) · view_model
      binding/                  # A(setState) / B(ValueNotifier) / C(Riverpod) 전파 전략
test/                           # 회귀 테스트(역순 tick·정지·에러·초성·집계) + 벤치마크
```

핵심 아이디어: **정합성은 data 한 곳에서 흡수 → SSOT Store에 dirty로 모음 → 프레임당
1회 flush → 바뀐 행만 갱신.** UI 전파 방식만 A/B/C로 교체해 동일 조건에서 성능을 비교하고
**B(행별 ValueNotifier)** 를 채택했습니다(근거: PERF.md).
