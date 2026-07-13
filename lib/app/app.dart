import 'package:flutter/material.dart';

import '../features/stock/application/stock_controller.dart';
import '../features/stock/presentation/screens/watchlist_screen.dart';
import 'candidate.dart';

/// 상세 진입/복귀를 감지해 목록 갱신을 pause/resume 하기 위한 라우트 옵저버.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

class WatchlistApp extends StatelessWidget {
  const WatchlistApp({
    super.key,
    required this.controller,
    required this.candidate,
  });

  final StockController controller;
  final Candidate candidate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '관심종목',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      navigatorObservers: [routeObserver],
      home: WatchlistScreen(controller: controller, candidate: candidate),
    );
  }
}
