import '../entities/connection_status.dart';
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
/// - 스트림 에러 흡수 후 [connection] 으로 노출(구독 유지)
///
/// application 계층은 이 인터페이스에만 의존한다(의존성 역전).
abstract class StockRepository {
  /// 세션 정적 메타 + 초기 시세 스냅샷. 시작 시 1회(반드시 [start] 이전).
  UniverseData loadUniverse();

  /// 정합성 검증을 통과한 시세 배치 스트림(도메인 타입).
  Stream<List<StockQuote>> quoteBatches();

  /// 연결/에러 상태 스트림.
  Stream<ConnectionStatus> connection();

  /// 실시간 수신 시작(벽시계). 벤치마크에서는 사용하지 않는다.
  void start();

  void dispose();
}
