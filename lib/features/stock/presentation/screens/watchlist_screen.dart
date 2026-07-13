import 'package:flutter/material.dart';

import '../../../../app/app.dart';
import '../../../../app/candidate.dart';
import '../../application/stock_controller.dart';
import '../binding/watchlist_binding.dart';
import '../widgets/search_field.dart';
import '../widgets/summary_bar.dart';
import '../widgets/top_movers_view.dart';
import 'stock_detail_screen.dart';

/// 화면 1 — 관심종목 목록.
///
/// 요약(종목수·시총) + Top-20 + 검색 + 실시간 2,000행 목록. 목록 본문은 후보
/// binding(A/B/C)이 담당한다. 상세로 진입하면 [RouteAware] 로 목록 갱신을 멈춘다.
class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({
    super.key,
    required this.controller,
    required this.candidate,
  });

  final StockController controller;
  final Candidate candidate;

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final WatchlistBinding _binding;

  @override
  void initState() {
    super.initState();
    _binding = WatchlistBinding.forCandidate(widget.candidate);
    // 프레임 정렬 flush 시작 + 실시간 수신 시작.
    widget.controller.attachVsync(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    // 상세가 위에 올라옴 → 목록 갱신 비용 정지.
    widget.controller.pauseFrameListeners();
  }

  @override
  void didPopNext() {
    // 상세에서 복귀 → 목록 갱신 재개(그 사이 누적된 dirty가 다음 프레임에 반영).
    widget.controller.resumeFrameListeners();
  }

  @override
  void dispose() {
    // 이 화면의 vsync로 만든 Ticker를 해제(수명 일치).
    widget.controller.detachVsync();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _openDetail(String code) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StockDetailScreen(
          controller: widget.controller,
          code: code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('관심종목'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.candidate.label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SummaryBar(controller: controller),
          const Divider(height: 1),
          TopMoversView(controller: controller),
          const Divider(height: 1),
          SearchField(onChanged: controller.setQuery),
          Expanded(
            child: ValueListenableBuilder<Set<String>?>(
              valueListenable: controller.filter,
              builder: (context, _, child) {
                final visible = controller.visibleCodes();
                if (visible.isEmpty) {
                  return const Center(child: Text('검색 결과 없음'));
                }
                return _binding.buildBody(controller, visible, _openDetail);
              },
            ),
          ),
        ],
      ),
    );
  }
}
