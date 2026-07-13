import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchlist_assignment/app/app.dart';
import 'package:watchlist_assignment/app/candidate.dart';
import 'package:watchlist_assignment/features/stock/application/stock_controller.dart';
import 'package:watchlist_assignment/features/stock/data/datasources/market_feed_datasource.dart';
import 'package:watchlist_assignment/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:watchlist_assignment/features/stock/presentation/widgets/quote_row.dart';

void main() {
  testWidgets('앱이 뜨고 실시간 목록·요약이 렌더된다 (후보 B)', (tester) async {
    final controller =
        StockController(StockRepositoryImpl(MarketFeedDataSource()))..init();

    await tester.pumpWidget(
      WatchlistApp(controller: controller, candidate: Candidate.b),
    );
    // 실시간 수신(Ticker + feed timer)을 몇 프레임 진행.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('관심종목'), findsOneWidget);
    expect(find.text('표시 종목'), findsOneWidget);
    expect(find.byType(QuoteRow), findsWidgets); // 2,000행 중 보이는 행 렌더

    // 정리: 위젯 트리 해제 후 컨트롤러(피드 타이머/티커) 정리.
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
