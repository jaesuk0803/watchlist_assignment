// 증분 집계 vs 전체 재계산 — 요약 1회 산출 비용 비교 (headless, 결정론적).
//
// 실행: flutter test test/aggregation_benchmark_test.dart
//
// 동일 상태(같은 seed로 300배치 반영)에서 "요약값(시총 합계 + Top-20)"을 한 번
// 만드는 비용을 두 방식으로 각각 N회 반복해 비교한다.
// - 전체 재계산(baseline A): 시총 O(n) 전체 합산 + Top-20 O(n log n) 전체 정렬
// - 증분(채택 B/C): 시총 O(1) 읽기 + Top-20 O(20) 트리 앞부분 읽기
import 'package:flutter_test/flutter_test.dart';
import 'package:watchlist_assignment/features/stock/application/stock_controller.dart';
import 'package:watchlist_assignment/features/stock/application/store/quote_store.dart';
import 'package:watchlist_assignment/features/stock/data/datasources/market_feed_datasource.dart';
import 'package:watchlist_assignment/features/stock/data/repositories/stock_repository_impl.dart';

import 'support/market_fakes.dart';

double _naiveMarketCap(QuoteStore store) {
  var sum = 0.0;
  for (final code in store.orderedCodes) {
    sum += store.quoteOf(code).price * store.metaOf(code).listedShares;
  }
  return sum;
}

List<String> _naiveTopMovers(QuoteStore store) {
  final codes = List<String>.from(store.orderedCodes);
  codes.sort((a, b) {
    final byRate =
        store.quoteOf(b).changeRate.compareTo(store.quoteOf(a).changeRate);
    if (byRate != 0) return byRate;
    return a.compareTo(b);
  });
  return codes.take(20).toList(growable: false);
}

void main() {
  test('증분 집계가 전체 재계산보다 요약 산출이 훨씬 싸다', () async {
    final ds = MarketFeedDataSource();
    final controller = StockController(StockRepositoryImpl(ds))..init();
    final store = controller.store;

    // 실제와 비슷한 상태로 만들기 위해 배치 300개 반영(등락률/가격 변동 누적).
    for (var i = 0; i < 300; i++) {
      ds.pump(1);
      await flush();
    }

    const iters = 3000;
    var sink = 0.0; // dead-code 제거 방지용 누산

    // 전체 재계산(baseline)
    final swNaive = Stopwatch()..start();
    for (var i = 0; i < iters; i++) {
      sink += _naiveMarketCap(store);
      sink += _naiveTopMovers(store).length;
    }
    swNaive.stop();

    // 증분(채택)
    final swIncremental = Stopwatch()..start();
    for (var i = 0; i < iters; i++) {
      sink += store.totalMarketCap;
      sink += store.topMoverCodes().length;
    }
    swIncremental.stop();

    final naiveMs = swNaive.elapsedMicroseconds / 1000.0;
    final incMs = swIncremental.elapsedMicroseconds / 1000.0;

    // ignore: avoid_print
    print('\n=========== 집계 비용 ($iters회 요약 산출) ===========');
    // ignore: avoid_print
    print('전체 재계산(baseline A) : ${naiveMs.toStringAsFixed(1)} ms');
    // ignore: avoid_print
    print('증분(채택 B/C)          : ${incMs.toStringAsFixed(1)} ms');
    // ignore: avoid_print
    print('배율                    : ${(naiveMs / incMs).toStringAsFixed(1)}x 빠름');
    // ignore: avoid_print
    print('(sink=$sink)');
    // ignore: avoid_print
    print('==================================================\n');

    expect(incMs, lessThan(naiveMs));
    controller.dispose();
  });
}
