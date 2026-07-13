import '../../../../seed/market_models.dart';
import '../../domain/entities/market_kind.dart';
import '../../domain/entities/stock_meta.dart';
import '../../domain/entities/stock_quote.dart';
import '../../domain/entities/trade_status.dart';

/// raw(seed) → 도메인 변환기(부패방지층).
///
/// tick 1개만 보면 계산이 끝나는 **무상태 1:1 변환**만 담당한다.
/// (여러 tick에 걸친 누적/집계는 application 계층의 책임)
///
/// seed 타입 `QuoteTick` 이 사실상 raw DTO 역할을 하므로 별도 DTO 계층을 두지 않고
/// 여기서 곧바로 도메인 엔티티로 변환한다(중복 제거 — DESIGN.md 참조).
class QuoteMapper {
  const QuoteMapper._();

  static MarketKind marketKind(MarketType type) => switch (type) {
        MarketType.kospi => MarketKind.kospi,
        MarketType.kosdaq => MarketKind.kosdaq,
      };

  static TradeStatus tradeStatus(QuoteStatus status) => switch (status) {
        QuoteStatus.active => TradeStatus.active,
        QuoteStatus.halted => TradeStatus.halted,
      };

  static StockMeta meta(QuoteSnapshotEntry entry) => StockMeta(
        code: entry.info.code,
        name: entry.info.name,
        market: marketKind(entry.info.market),
        listedShares: entry.info.listedShares,
        previousClose: entry.previousClose,
      );

  /// [tick] 을 [previousClose] 기준으로 도메인 시세로 변환(등락률/등락폭 계산).
  static StockQuote quote(QuoteTick tick, double previousClose) {
    final changeAmount = tick.price - previousClose;
    final changeRate =
        previousClose == 0 ? 0.0 : (changeAmount / previousClose) * 100.0;
    return StockQuote(
      code: tick.code,
      price: tick.price,
      dayVolume: tick.dayVolume,
      status: tradeStatus(tick.status),
      timestampMs: tick.timestampMs,
      changeRate: changeRate,
      changeAmount: changeAmount,
    );
  }

  /// 초기 스냅샷 항목 → 도메인 시세(등락률 0, timestamp 0, active).
  static StockQuote fromSnapshot(QuoteSnapshotEntry entry) {
    final changeAmount = entry.price - entry.previousClose;
    final changeRate = entry.previousClose == 0
        ? 0.0
        : (changeAmount / entry.previousClose) * 100.0;
    return StockQuote(
      code: entry.info.code,
      price: entry.price,
      dayVolume: entry.dayVolume,
      status: TradeStatus.active,
      timestampMs: 0,
      changeRate: changeRate,
      changeAmount: changeAmount,
    );
  }
}
