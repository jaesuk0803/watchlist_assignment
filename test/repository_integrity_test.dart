import 'package:flutter_test/flutter_test.dart';
import 'package:watchlist_assignment/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:watchlist_assignment/features/stock/domain/entities/stock_quote.dart';
import 'package:watchlist_assignment/features/stock/domain/entities/trade_status.dart';
import 'package:watchlist_assignment/seed/market_models.dart';

import 'support/market_fakes.dart';

void main() {
  test('역순/지연 tick은 폐기되어 가격이 과거로 되돌아가지 않는다', () async {
    final fake = FakeTickSource([snap('000001', 1000)]);
    final repo = StockRepositoryImpl(fake);
    repo.loadUniverse();

    final received = <StockQuote>[];
    repo.quoteBatches().listen((b) => received.addAll(b));

    fake.emit([tick('000001', 1100, 100)]);
    await flush();
    fake.emit([tick('000001', 1050, 50)]); // 더 오래된 tick → 폐기
    await flush();
    fake.emit([tick('000001', 1200, 150)]);
    await flush();

    expect(received.map((q) => q.price).toList(), [1100, 1200]);

    repo.dispose();
  });

  test('거래정지 tick은 halted 상태로 매핑된다', () async {
    final fake = FakeTickSource([snap('000001', 1000)]);
    final repo = StockRepositoryImpl(fake);
    repo.loadUniverse();

    final received = <StockQuote>[];
    repo.quoteBatches().listen((b) => received.addAll(b));

    fake.emit([tick('000001', 1000, 10, status: QuoteStatus.halted)]);
    await flush();

    expect(received.single.status, TradeStatus.halted);

    repo.dispose();
  });

  test('스트림 에러가 와도 구독이 유지되고 에러는 원시로 통과된다', () async {
    // repository는 에러를 삼키지 않고 errors()로 통과시키되 구독은 유지한다.
    // (정지 감지/디바운스 복구 같은 상태 정책은 ConnectionMonitor의 책임)
    final fake = FakeTickSource([snap('000001', 1000)]);
    final repo = StockRepositoryImpl(fake);
    repo.loadUniverse();

    final received = <StockQuote>[];
    final errors = <Object>[];
    repo.quoteBatches().listen((b) => received.addAll(b));
    repo.errors().listen(errors.add);

    fake.emit([tick('000001', 1100, 100)]);
    await flush();
    fake.emitError(Exception('일시적 오류'));
    await flush();
    fake.emit([tick('000001', 1200, 200)]); // 에러 후에도 구독 유지 → 정상 처리
    await flush();

    expect(errors, hasLength(1)); // 에러가 통과됨
    expect(received.map((q) => q.price).toList(), [1100, 1200]); // 구독 생존

    repo.dispose();
  });

  test('등락률/등락폭이 전일종가 기준으로 계산된다', () async {
    final fake = FakeTickSource([snap('000001', 1000)]);
    final repo = StockRepositoryImpl(fake);
    repo.loadUniverse();

    final received = <StockQuote>[];
    repo.quoteBatches().listen((b) => received.addAll(b));

    fake.emit([tick('000001', 1100, 100)]);
    await flush();

    expect(received.single.changeAmount, 100);
    expect(received.single.changeRate, closeTo(10.0, 1e-9));

    repo.dispose();
  });
}
