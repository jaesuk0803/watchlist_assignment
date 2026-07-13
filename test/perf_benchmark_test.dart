// 재현 가능한 벤치마크 (headless, Dart VM).
//
// 실행: flutter test test/perf_benchmark_test.dart
//
// MarketFeed.pump() 로 동일 seed(20260703)의 결정론적 tick 수열을 A/B/C에 똑같이
// 흘려 **프레임당 rebuild된 행 수**와 **build 소요시간**을 비교한다.
// - A(baseline): 매 프레임 보이는 행 전부 rebuild (RepaintBoundary 없음)
// - B/C: dirty 종목(보이는 것만) rebuild → 범위 대폭 축소
//
// rebuild 행 수는 seed 고정이라 실행마다 동일(결정론적). build 시간(elapsedMs)은
// 머신에 따라 다르므로 절대값보다 A 대비 상대 개선을 본다.
//
// (실기기 프레임 타임/래스터 시간은 `flutter run --profile` + DevTools Performance
//  로 측정 — README/PERF.md 참조. 여기선 rebuild 범위를 결정론적으로 재현한다.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchlist_assignment/app/candidate.dart';
import 'package:watchlist_assignment/features/stock/application/stock_controller.dart';
import 'package:watchlist_assignment/features/stock/data/datasources/market_feed_datasource.dart';
import 'package:watchlist_assignment/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:watchlist_assignment/features/stock/presentation/binding/watchlist_binding.dart';
import 'package:watchlist_assignment/features/stock/presentation/widgets/quote_row.dart';

const int _frames = 200;

Future<_Result> _run(WidgetTester tester, Candidate candidate) async {
  final ds = MarketFeedDataSource(); // 기본 seed로 결정론적
  // A(baseline)만 요약을 전체 재계산(순진), B/C는 증분 집계.
  final controller = StockController(
    StockRepositoryImpl(ds),
    naiveSummary: candidate == Candidate.a,
  )..init();
  final binding = WatchlistBinding.forCandidate(candidate);
  final visible = controller.visibleCodes();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: binding.buildBody(controller, visible, (_) {})),
    ),
  );
  await tester.pump();

  QuoteRowMetrics.reset();
  final sw = Stopwatch()..start();
  for (var f = 0; f < _frames; f++) {
    ds.pump(1); // 배치 1개 방출
    await tester.idle(); // repo→store 비동기 반영 flush
    controller.flushFrame(); // dirty → 전파(A는 전체 setState)
    await tester.pump(); // 프레임 빌드
  }
  sw.stop();

  final result = _Result(
    candidate: candidate,
    frames: _frames,
    rowBuilds: QuoteRowMetrics.builds,
    elapsedMs: sw.elapsedMilliseconds,
  );
  controller.dispose();
  return result;
}

void main() {
  testWidgets('A/B/C rebuild 범위 · build 시간 비교 (pump $_frames프레임)',
      (tester) async {
    // 더 많은 행이 보이도록 큰 화면으로(뷰포트 밖은 어차피 빌드 안 됨).
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final results = <_Result>[];
    for (final c in [Candidate.a, Candidate.b, Candidate.c]) {
      results.add(await _run(tester, c));
    }

    final a = results.firstWhere((r) => r.candidate == Candidate.a);
    final b = results.firstWhere((r) => r.candidate == Candidate.b);

    // ignore: avoid_print
    print('\n================ PERF (pump $_frames frames) ================');
    // ignore: avoid_print
    print('candidate               rowBuilds   builds/frame   elapsedMs');
    for (final r in results) {
      // ignore: avoid_print
      print('${r.candidate.label.padRight(22)} '
          '${r.rowBuilds.toString().padLeft(9)}   '
          '${(r.rowBuilds / r.frames).toStringAsFixed(1).padLeft(11)}   '
          '${r.elapsedMs.toString().padLeft(9)}');
    }
    // ignore: avoid_print
    print('\nB rebuild 절감: '
        '${(100 * (1 - b.rowBuilds / a.rowBuilds)).toStringAsFixed(1)}% (A 대비)');
    // ignore: avoid_print
    print('=========================================================\n');

    // 회귀 가드: B는 A보다 rebuild가 확실히 적어야 한다.
    expect(b.rowBuilds, lessThan(a.rowBuilds));
  });
}

class _Result {
  const _Result({
    required this.candidate,
    required this.frames,
    required this.rowBuilds,
    required this.elapsedMs,
  });

  final Candidate candidate;
  final int frames;
  final int rowBuilds;
  final int elapsedMs;
}
