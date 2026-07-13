import 'market_kind.dart';

/// 종목의 정적 메타데이터. 세션 동안 바뀌지 않는다.
///
/// seed의 `SymbolInfo` + 스냅샷의 `previousClose` 를 합쳐 도메인 단위로 만든 값.
/// 등락률/등락폭/시가총액 계산의 고정 기준값(previousClose, listedShares)을 담는다.
class StockMeta {
  const StockMeta({
    required this.code,
    required this.name,
    required this.market,
    required this.listedShares,
    required this.previousClose,
  });

  final String code;
  final String name;
  final MarketKind market;
  final int listedShares;

  /// 전일 종가. 등락률/등락폭의 기준값(세션 고정).
  final double previousClose;
}
