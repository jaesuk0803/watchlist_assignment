import 'package:flutter_test/flutter_test.dart';
import 'package:watchlist_assignment/features/stock/application/services/market_cap_aggregator.dart';
import 'package:watchlist_assignment/features/stock/application/services/top_movers_tracker.dart';

void main() {
  group('MarketCapAggregator (증분 시총)', () {
    test('seed 합계 = sum(price*shares)', () {
      final agg = MarketCapAggregator();
      agg.seed('A', 100, 10); // 1000
      agg.seed('B', 200, 5); // 1000
      expect(agg.total, 2000);
    });

    test('update는 델타만 반영', () {
      final agg = MarketCapAggregator();
      agg.seed('A', 100, 10); // 1000
      agg.seed('B', 200, 5); // 1000
      agg.update('A', 150, 10); // +500 → 1500
      expect(agg.total, 2500);
      agg.update('A', 100, 10); // -500 → 원복
      expect(agg.total, 2000);
    });
  });

  group('TopMoversTracker (증분 순위)', () {
    test('등락률 내림차순, 동점은 코드 오름차순', () {
      final t = TopMoversTracker(limit: 3);
      t.seed('000003', 1.0);
      t.seed('000001', 2.0);
      t.seed('000002', 2.0); // 000001과 동점 → 코드 앞선 000001 먼저
      t.seed('000004', -1.0);
      expect(t.top(), ['000001', '000002', '000003']);
    });

    test('갱신 시 순위가 라이브로 바뀜(전체 재정렬 없이)', () {
      final t = TopMoversTracker(limit: 2);
      t.seed('A', 1.0);
      t.seed('B', 2.0);
      t.seed('C', 0.5);
      expect(t.top(), ['B', 'A']);
      t.update('C', 5.0); // C가 1위로
      expect(t.top(), ['C', 'B']);
      t.update('B', -3.0); // B가 하락 → 밀려남
      expect(t.top(), ['C', 'A']);
    });

    test('limit 초과분은 제외', () {
      final t = TopMoversTracker(limit: 2);
      for (var i = 0; i < 10; i++) {
        t.seed('C${i.toString().padLeft(3, '0')}', i.toDouble());
      }
      expect(t.top().length, 2);
      expect(t.top(), ['C009', 'C008']);
    });
  });
}
