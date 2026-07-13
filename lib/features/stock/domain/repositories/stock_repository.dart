import '../entities/stock_meta.dart';
import '../entities/stock_quote.dart';

/// 세션 시작 시점의 정적 메타 + 초기 시세 묶음.
class UniverseData {
  const UniverseData({required this.metas, required this.initialQuotes});

  final List<StockMeta> metas;
  final List<StockQuote> initialQuotes;
}

/// 시세 데이터 소스에 대한 도메인 계약(추상).
///
/// 구현체(data 계층)는 seed의 `MarketFeed` 를 감싸 다음을 책임진다:
/// - feed를 **단 한 번만** 구독 (broadcast 중복 소비 방지)
/// - **정합성 경계**: timestampMs 기준 역순 tick 폐기
/// - raw `QuoteTick` → 도메인 `StockQuote` 매핑(등락률/등락폭 계산 포함)
/// - 스트림 에러를 삼키지 않고 [errors] 로 원시 통과(구독은 유지)
///
/// 연결 상태 "정책"(정지 감지·디바운스 복구)은 프레임 루프를 가진 application
/// 계층(ConnectionMonitor)이 판단한다. repository는 raw 신호만 노출한다.
///
/// application 계층은 이 인터페이스에만 의존한다(의존성 역전).
abstract class StockRepository {
  /// 세션 정적 메타 + 초기 시세 스냅샷. 시작 시 1회(반드시 [start] 이전).
  UniverseData loadUniverse();

  /// 정합성 검증을 통과한 시세 배치 스트림(도메인 타입).
  Stream<List<StockQuote>> quoteBatches();

  /// feed에서 발생한 원시 스트림 에러(구독은 유지된다). 상태 해석은 소비자 몫.
  Stream<Object> errors();

  /// 실시간 수신 시작(벽시계). 벤치마크에서는 사용하지 않는다.
  void start();

  void dispose();
}
