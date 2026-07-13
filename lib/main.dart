import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/candidate.dart';
import 'features/stock/application/stock_controller.dart';
import 'features/stock/data/datasources/market_feed_datasource.dart';
import 'features/stock/data/repositories/stock_repository_impl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final candidate = Candidate.fromEnv();

  // DI 조립: feed → datasource → repository(정합성 경계) → controller(조율).
  // baseline A는 요약을 매 프레임 전체 재계산(순진한 구현), B/C는 증분 집계.
  final repository = StockRepositoryImpl(MarketFeedDataSource());
  final controller = StockController(
    repository,
    naiveSummary: candidate == Candidate.a,
  )..init();

  runApp(
    WatchlistApp(
      controller: controller,
      candidate: candidate,
    ),
  );
}
