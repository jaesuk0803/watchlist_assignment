import 'dart:async';

import '../../../../seed/market_models.dart';
import '../../domain/entities/stock_meta.dart';
import '../../domain/entities/stock_quote.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/market_feed_datasource.dart';
import '../mappers/quote_mapper.dart';

/// [StockRepository] 구현 — 정합성 경계(부패방지층)의 핵심.
///
/// 책임:
/// 1. feed를 **단 한 번만** 구독한다(broadcast 중복 소비 방지 = SSOT 단일 진입).
/// 2. **역순 tick 폐기**: 종목별 최신 timestampMs 를 기억하고, 더 오래된 tick은
///    버린다 → 표시 가격이 과거로 되돌아가지 않는다.
/// 3. raw → 도메인 매핑(등락률/등락폭 계산).
/// 4. **스트림 에러 통과**: onError 를 잡아 구독을 유지(cancelOnError: false)한 채
///    [errors] 로 원시 에러만 흘려보낸다. 정지/복구 판정은 application 계층
///    (ConnectionMonitor)의 몫이며, 여기서 상태를 만들지 않는다.
class StockRepositoryImpl implements StockRepository {
  StockRepositoryImpl(this._ds) {
    _subscribe();
  }

  final TickSource _ds;

  /// 종목별 전일종가(스냅샷에서 1회 확보). 등락률 계산 기준.
  final Map<String, double> _previousClose = {};

  /// 종목별 마지막으로 반영한 timestampMs. 역순 tick 판별용.
  final Map<String, int> _lastTimestampMs = {};

  StreamSubscription<List<QuoteTick>>? _sub;

  final StreamController<List<StockQuote>> _batches =
      StreamController<List<StockQuote>>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  @override
  UniverseData loadUniverse() {
    final snapshot = _ds.initialSnapshot();
    final metas = <StockMeta>[];
    final initialQuotes = <StockQuote>[];
    for (final entry in snapshot) {
      _previousClose[entry.info.code] = entry.previousClose;
      metas.add(QuoteMapper.meta(entry));
      initialQuotes.add(QuoteMapper.fromSnapshot(entry));
    }
    return UniverseData(metas: metas, initialQuotes: initialQuotes);
  }

  @override
  Stream<List<StockQuote>> quoteBatches() => _batches.stream;

  @override
  Stream<Object> errors() => _errors.stream;

  @override
  void start() => _ds.start();

  void _subscribe() {
    _sub = _ds.ticks.listen(
      _onBatch,
      onError: _onError,
      cancelOnError: false, // 에러가 와도 구독 유지 → 다음 배치로 복구
    );
  }

  void _onBatch(List<QuoteTick> batch) {
    final out = <StockQuote>[];
    for (final tick in batch) {
      final last = _lastTimestampMs[tick.code];
      // 역순/지연 tick 폐기: 이미 더 최신을 반영했으면 무시.
      if (last != null && tick.timestampMs < last) continue;
      _lastTimestampMs[tick.code] = tick.timestampMs;
      out.add(
        QuoteMapper.quote(tick, _previousClose[tick.code] ?? tick.price),
      );
    }
    if (out.isNotEmpty) _batches.add(out);
  }

  void _onError(Object error, StackTrace stackTrace) {
    // 구독은 유지(재구독 없음)한 채 원시 에러만 통과시킨다.
    _errors.add(error);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _batches.close();
    _errors.close();
    _ds.dispose();
  }
}
