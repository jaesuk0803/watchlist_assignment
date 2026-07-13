import 'dart:async';

import 'package:watchlist_assignment/features/stock/data/datasources/market_feed_datasource.dart';
import 'package:watchlist_assignment/seed/market_models.dart';

/// 임의의 tick/에러를 주입할 수 있는 fake 시세 소스(정합성/조율 테스트용).
class FakeTickSource implements TickSource {
  FakeTickSource(this._snapshot);

  final List<QuoteSnapshotEntry> _snapshot;
  final StreamController<List<QuoteTick>> _ctrl =
      StreamController<List<QuoteTick>>.broadcast();

  @override
  List<QuoteSnapshotEntry> initialSnapshot() => _snapshot;

  @override
  Stream<List<QuoteTick>> get ticks => _ctrl.stream;

  @override
  void start() {}

  @override
  void dispose() => _ctrl.close();

  void emit(List<QuoteTick> batch) => _ctrl.add(batch);
  void emitError(Object error) => _ctrl.addError(error);
}

QuoteSnapshotEntry snap(
  String code,
  double prevClose, {
  String? name,
  int listedShares = 1000000,
}) =>
    QuoteSnapshotEntry(
      info: SymbolInfo(
        code: code,
        name: name ?? '테스트$code',
        market: MarketType.kospi,
        listedShares: listedShares,
      ),
      previousClose: prevClose,
      price: prevClose,
      dayVolume: 0,
    );

QuoteTick tick(
  String code,
  double price,
  int ts, {
  QuoteStatus status = QuoteStatus.active,
  int volume = 0,
}) =>
    QuoteTick(
      code: code,
      price: price,
      dayVolume: volume,
      timestampMs: ts,
      status: status,
    );

/// 브로드캐스트 스트림 이벤트가 리스너에 전달되도록 마이크로태스크를 비운다.
Future<void> flush() => Future<void>.delayed(Duration.zero);
