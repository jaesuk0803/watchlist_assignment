# DESIGN.md — 실시간 관심종목 앱 아키텍처

> 요약: **feature-first + 실용적 Clean(4계층)** 위에, 성능의 핵심인 UI 전파 방식만
> A/B/C 후보로 갈아끼워 동일 조건에서 비교했습니다. 정합성(역순 tick·정지·에러)은
> **data 계층 한 곳(부패방지층)** 에서 흡수하고, 고빈도 갱신은 **SSOT Store + dirty
> set + 프레임 정렬 coalescing + 증분 집계**로 처리합니다. 채택은 **후보 B(행별
> ValueNotifier)** 입니다(근거: PERF.md).

---

## 1. 계층 / 경계 / 의존 방향

```
seed/ (수정 금지)  ─ MarketFeed, QuoteTick, SymbolInfo ...
        │  (오직 data 계층만 seed를 import)
        ▼
data/           datasource(feed 단일 구독) · mapper(raw→도메인) · repository(정합성 경계)
        │  (도메인 인터페이스 StockRepository 반환)
        ▼
domain/         엔티티(StockMeta/StockQuote/Ohlc/…) · repository 추상 · enum
        ▲
application/    StockController(조율) · QuoteStore(SSOT) · 증분집계 · coalescer · 검색인덱스
        │  (presentation은 application만 알고, data/seed는 모름)
        ▼
presentation/   screens · widgets(공유) · view_model · binding(A/B/C 전파 전략)
```

의존은 항상 **안쪽(도메인)** 을 향합니다. presentation은 seed 타입을 절대 모르고,
seed 타입이 새는 것을 막는 경계가 `data/mappers` + `data/repositories` 입니다.

- **feature-first**: 지금은 `stock` 하나지만, 관심종목/뉴스/차트처럼 기능이 늘 때
  화면·상태·데이터가 기능 폴더 안에서 응집되도록 `features/stock/{domain,data,application,presentation}` 로 잡았습니다.
- **application 계층을 분리한 이유**: 이 앱의 난이도는 "도메인 규칙"이 아니라
  "고빈도 상태를 어떻게 모으고 언제 UI에 흘리느냐"에 있습니다. SSOT Store, dirty set,
  coalescer, 증분 집계, 검색 인덱스는 순수 도메인도 아니고 UI도 아닌 **상태·성능
  로직**이라 별도 계층으로 뺐습니다. (`StockController` 가 use-case/서비스 역할)

---

## 2. 데이터 흐름 (단방향)

```
MarketFeed.ticks(배치)
  → [data] repository: 역순 tick 폐기 + raw→도메인 매핑 + 에러 흡수
  → [app]  QuoteStore.applyBatch(): 현재시세 갱신 + dirty 누적 + 증분집계(시총/Top20)
  → [app]  FrameCoalescer(Ticker): 프레임당 1회 flush
  → [app]  StockController._onFrame(): dirty를 걷어 binding(프레임 리스너)에 전달
  → [ui]   binding(A/B/C): 바뀐 행만 갱신
```

핵심은 **"tick 유입 주기(초당 수천)"와 "UI 반영 주기(프레임당 1회)"를 분리**한 것입니다.
Store는 tick마다 조용히 상태만 갱신하고, 화면은 프레임당 한 번만 dirty를 소비합니다.

---

## 3. 상태 관리 방식과 그 이유

- **SSOT Store (`QuoteStore`)**: 모든 화면이 참조하는 단일 상태 원본. 종목별 현재
  시세/OHLC를 Map으로 보유하고, 바뀐 종목코드를 **dirty set** 에 모읍니다.
- **전파(propagation)만 후보화**: 도메인/데이터/스토어/집계는 1벌 그대로 두고,
  "Store의 변화를 위젯에 어떻게 알리나"만 A/B/C로 교체합니다(`presentation/binding`).
  → 성능 차이가 **전파 방식에서만** 나오도록 통제해 공정 비교가 됩니다.
  - **A. setState(baseline)**: 과제가 정의한 "가장 순진한 형태" 3가지를 모두 반영 —
    ① 프레임마다 목록 전체 rebuild(dirty 무시) ② 행에 RepaintBoundary 없음
    ③ 요약(시총/Top-20)을 매 프레임 전체 순회로 재계산. PERF before.
  - **B. 행별 ValueNotifier (채택)**: 종목당 `ValueNotifier<QuoteVM>`. 각 행은 자기
    notifier만 `ValueListenableBuilder` 로 구독 → dirty 행만 rebuild(잎사귀 단위).
  - **C. Riverpod family**: 개념은 B와 동일하나 notifier 대신 provider/ref 그래프로
    의존을 추적. 선언적이지만 provider/ref bookkeeping 오버헤드가 있음.
- 전환: `--dart-define=CANDIDATE=a|b|c` (기본 b).

---

## 4. 에러 / 엣지 모델

경계 원칙: **"정합성은 안(도메인)으로 새기 전에 data에서 끝낸다."** application/UI는
언제나 "깨끗한 최신값"만 봅니다.

- **지연·역순 tick** — `StockRepositoryImpl` 이 종목별 마지막 `timestampMs` 를 기억하고,
  더 오래된 tick은 **폐기**합니다. 도착 순서가 아니라 timestamp가 진실이므로 표시
  가격이 과거로 되돌아가지 않습니다. (회귀 테스트: `repository_integrity_test`)
- **거래정지(halt)** — tick의 `status` 를 그대로 도메인 `TradeStatus.halted` 로 매핑.
  가격은 직전가로 고정되어 오므로 그대로 반영하면 됩니다. 별도 "재개 신호"가 없으니
  이후 `active` tick이 오면 자연히 해제로 처리됩니다(추가 상태 머신 불필요).
  - **파생값 정책**: 정지 종목도 **시총·Top-20에 계속 포함**합니다(가격이 고정될 뿐
    시장에서 사라진 게 아님). 다만 가격 고정이라 OHLC high/low에는 영향이 없습니다.
  - **표시 수(displayedCount)**: 정지 종목도 "표시 중"으로 셉니다(화면에 보이므로).
- **일시적 스트림 에러** — 구독을 `cancelOnError: false` 로 유지하고, `onError` 를 잡아
  **삼키지 않고** `errors()` 로 원시 통과시킵니다(repository는 상태를 만들지 않음).
  구독은 그대로 살아 다음 배치로 복구됩니다. 연결 "상태 정책"은 아래 `ConnectionMonitor`
  가 판단합니다.
- **연결 상태 판정(`ConnectionMonitor`)** — 서로 다른 두 실패 모드를 구분해 다룹니다.
  책임을 repository(원시 신호)와 application(정책)으로 분리했고, **타이머·벽시계를 쓰지
  않고** 프레임/배치 카운트만으로 판정해 결정론적 유닛 테스트가 가능합니다
  (`connection_monitor_test`).
  - **명시적 에러 → `unstable`**: `onError` 이벤트가 오면 즉시 불안정으로 표시.
  - **조용한 정지(silent stall) → `stalled`**: 에러 이벤트조차 없이 배치가 끊기는 경우는
    이벤트로 감지할 수 없습니다(안 오는 것은 이벤트가 아님). 그래서 "마지막 배치 이후
    경과 **프레임 수**"로 감시합니다. 별도 `Timer` 를 만들지 않고 **이미 있는 vsync 프레임
    루프(`_onFrame`)를 하트비트로 재사용**해, `stallFrames(≈90프레임=1.5s)` 초과 시 정지로
    판정합니다. UI는 이때 더 강한 빨강 배너("실시간 수신 지연·재연결 대기 중")를 띄웁니다.
    → 화면이 조용히 멈춘 것처럼 보이는 상황을 사용자에게 명확히 알립니다.
  - **디바운스 복구**: 에러/정지 직후 배치 1건으로 바로 복구하지 않고, **연속 정상 배치
    `recoveryBatches(=60)` 건**이 쌓인 뒤에야 `live` 로 되돌립니다. 서킷 브레이커의
    successThreshold와 같은 방식으로, flapping(깜빡임)에 배너가 요동치는 것을 막습니다.
  - UI: `unstable`(주황) / `stalled`(빨강) 배너로 구분해 표시. (무시가 아니라 표현)
  - (회귀 테스트: 에러 후에도 배치가 계속 처리됨 / 디바운스 복구 / 정지 감지 / flapping 리셋)

---

## 5. 성능 설계 (요약, 상세는 PERF.md)

- **dirty set + 프레임 coalescing**: tick은 초당 수천이지만 flush는 프레임당 1회
  (`Ticker` = vsync 정렬). 같은 종목이 프레임 내 여러 번 바뀌어도 rebuild는 1회로 합쳐짐.
- **rebuild 범위 축소**: dirty에 든 종목의 행만 갱신(B/C). baseline 대비 **약 93.5%**
  rebuild 감소(측정치 PERF.md).
- **증분 집계(전체 재계산 금지)** — baseline 대비 요약 산출 **약 579× 빠름**(PERF §1-1):
  - 시총 합계 = 종목별 (가격×상장주식수) 기여분을 기억하고 **델타만** 가감 → 갱신당 O(1).
  - Top-20 = `SplayTreeSet`(등락률 desc, 코드 asc)로 유지, 종목당 remove+insert O(log n),
    상위 20 조회 O(20). **매 tick 전체 정렬(O(n log n)) 없음.**
- **검색 인덱스**: 시작 시 1회 구축(종목명 불변). 필터는 **keystroke debounce(200ms)** 시점에만
  수행하고 **매 tick 재계산하지 않음**. 초성 검색은 완성형 음절→초성 변환 후 부분일치.
- **신선도 200ms vs 60fps 트레이드오프**: coalescing 단위를 **1프레임(≈16.6ms)** 으로
  잡았습니다. 최대 stale ≈ 1프레임 ≪ 200ms라 신선도 제약을 크게 만족하면서, 프레임당
  작업량은 dirty 행으로 제한돼 60fps를 지킵니다. (신선도를 위해 프레임보다 더 자주
  flush할 이유가 없고, 프레임보다 드물게 몰면 신선도가 나빠지므로 프레임 단위가 최적점)
- **상세 화면 수명 관리**: 상세 진입 시 `RouteAware` 로 목록의 프레임 리스너를 pause
  (목록 rebuild 비용 정지). 이때 dirty는 **소비하지 않고 남겨** 복귀 시 유실 없이 반영.
  상세는 자체 `Ticker` 로 store를 읽어 독립 갱신하고, 스파크라인은 고정 길이 링버퍼(60)로
  유지해 히스토리 버퍼가 무한 증가하지 않게 합니다.

---

## 6. 검토했지만 기각한 대안 (무엇을/왜)

1. **feed를 화면마다 직접 구독** — broadcast라 여러 번 붙을 수 있지만, 구독마다 정합성
   로직이 중복되고 소비 계층이 제각각이 됩니다. → **repository 단일 구독 + SSOT** 로 반려.
2. **tick마다 즉시 setState/rebuild (throttle 없음)** — 가장 단순하지만 초당 수천 rebuild로
   프레임을 못 지킵니다(baseline이 이 형태, PERF의 before). → **dirty set + 프레임 coalescing** 채택.
3. **요약값(시총/Top-20)을 매 프레임 전체 순회로 재계산** — 2,000종목 재곱·재정렬은
   프레임 예산을 초과. → **증분 델타 + SplayTreeSet** 로 반려.
4. **전역 단일 상태를 통째로 rebuild하는 상태관리(예: 단일 ChangeNotifier/전역 provider
   1개)** — 한 종목만 바뀌어도 전 구독자가 rebuild. → **종목 단위 leaf 구독(B/C)** 채택.
5. **상태관리로 Riverpod 채택(C)** — 선언적이고 파생 상태 관리가 깔끔하지만, 이 핫패스에선
   provider/ref bookkeeping 오버헤드로 build 시간이 B보다 큼(PERF: C 870ms vs B 464ms).
   → 성능 우선이라 **B 채택**, C는 비교/근거로 남김.
6. **초성 검색 라이브러리 도입** — 규칙이 단순·고정이고 의존성 없이 결정론적이라
   직접 구현(≈30줄). 면접에서 동작을 설명하기도 쉬움. → 외부 의존 반려.
7. **raw `QuoteTick` 을 UI까지 그대로 사용** — seed 타입이 전 계층에 새어 결합↑, 등락률 등
   파생값 계산 위치가 흩어짐. → **경계에서 도메인 엔티티로 변환** 채택.
8. **연결 감시를 별도 `Timer.periodic` 워치독으로 구현** — 정지 감지의 정석은 주기적
   깨어남(TCP keepalive/WS ping/k8s liveness)이라 타이머 자체는 편법이 아닙니다. 다만 이
   UI 앱엔 **이미 vsync 프레임 루프라는 하트비트**가 있어, 두 번째 타이머를 두는 건 중복입니다.
   또 벽시계(`DateTime.now`) 의존은 결정론적 테스트를 어렵게 합니다. → **프레임 루프 재사용
   + 프레임/배치 카운트 기반**(`ConnectionMonitor`)으로 반려. 복구도 시간창 대신 **연속 성공
   카운트(서킷 브레이커 successThreshold)** 로 처리해 타이머·시계를 완전히 제거했습니다.

---

## 7. 의도적으로 생략/축약한 것

- **KOSPI/KOSDAQ 탭 분리**: 요구 화면에는 없어 목록은 통합(가나다순) + 검색에 집중.
  분리는 `visibleCodes()` 에 시장 필터 한 줄 추가로 확장 가능.
- **on-device 프레임/래스터 타임 표**: 자동화 가능한 결정론적 지표(rebuild 범위, build
  시간)를 헤드리스로 재현했습니다. 실기기 프레임 타임은 `flutter run --profile` +
  DevTools로 확인하는 절차를 README/PERF.md에 남겼습니다.
- **use-case 클래스 남발 금지**: 통과만 하는 use-case를 만드는 대신 `StockController` 가
  조율(use-case) 역할을 겸합니다. 의미 있는 로직(검색 인덱스·집계)은 별도 서비스로 분리.
