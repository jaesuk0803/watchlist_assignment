import 'package:flutter_test/flutter_test.dart';
import 'package:watchlist_assignment/features/stock/application/stock_controller.dart';
import 'package:watchlist_assignment/features/stock/data/repositories/stock_repository_impl.dart';

import 'support/market_fakes.dart';

void main() {
  test('배치 반영 후 dirty·시총·Top순위가 프레임 flush에서 갱신된다', () async {
    final fake = FakeTickSource([
      snap('000001', 1000, name: '가온전자', listedShares: 10),
      snap('000002', 2000, name: '나래화학', listedShares: 10),
      snap('000003', 3000, name: '다온바이오', listedShares: 10),
    ]);
    final controller = StockController(StockRepositoryImpl(fake))..init();

    // 초기 시총 = (1000+2000+3000)*10 = 60000
    expect(controller.store.totalMarketCap, 60000);

    // 000003이 +10% → 3300
    fake.emit([tick('000003', 3300, 100)]);
    await flush();
    controller.flushFrame();

    expect(controller.store.quoteOf('000003').price, 3300);
    // 000003 기여분 30000 → 33000 (+3000)
    expect(controller.store.totalMarketCap, 63000);
    // Top-1은 000003(등락률 +10%)
    expect(controller.store.topMoverCodes().first, '000003');

    controller.dispose();
  });

  test('검색 필터는 표시 수만 바꾸고 시총은 전체 기준을 유지한다', () async {
    final fake = FakeTickSource([
      snap('000001', 1000, name: '가온전자', listedShares: 10),
      snap('000002', 2000, name: '나래화학', listedShares: 10),
    ]);
    final controller = StockController(StockRepositoryImpl(fake))..init();

    controller.setQuery('가온'); // 000001만
    expect(controller.visibleCodes(), ['000001']);
    expect(controller.summary.value.displayedCount, 1);
    // 시총은 전체 기준 유지
    expect(controller.summary.value.totalMarketCap, 30000);

    controller.dispose();
  });
}
