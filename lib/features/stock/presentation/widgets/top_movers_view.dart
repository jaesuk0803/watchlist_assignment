import 'package:flutter/material.dart';

import '../../application/stock_controller.dart';
import '../../application/summary_state.dart';
import '../formatters.dart';
import '../view_models/quote_vm.dart';
import 'quote_row.dart';

/// 등락률 Top-20(실시간 순위). 가로 스크롤 칩 리스트.
///
/// `controller.summary` 만 구독 → 프레임당 1회 갱신. 순위 유지는 application의
/// 증분 tracker가 담당(매 tick 전체 재정렬 없음).
///
/// 초기엔 모든 등락률이 0%(스냅샷 price==전일종가)이므로 "집계 중"을 표시하다가
/// tick이 흐르면 실제 순위로 전환한다.
class TopMoversView extends StatelessWidget {
  const TopMoversView({super.key, required this.controller});

  final StockController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SummaryState>(
      valueListenable: controller.summary,
      builder: (context, summary, _) {
        final codes = summary.topMoverCodes;
        final hasMovement = codes.any(
          (c) => controller.store.quoteOf(c).changeRate.abs() > 1e-9,
        );
        return SizedBox(
          height: 76,
          child: !hasMovement
              ? const _Collecting()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: codes.length,
                  itemBuilder: (context, i) {
                    final code = codes[i];
                    final meta = controller.store.metaOf(code);
                    final quote = controller.store.quoteOf(code);
                    return _MoverChip(
                      rank: i + 1,
                      name: meta.name,
                      changeRate: quote.changeRate,
                    );
                  },
                ),
        );
      },
    );
  }
}

class _MoverChip extends StatelessWidget {
  const _MoverChip({
    required this.rank,
    required this.name,
    required this.changeRate,
  });

  final int rank;
  final String name;
  final double changeRate;

  @override
  Widget build(BuildContext context) {
    final dir = changeRate > 0
        ? PriceDirection.up
        : (changeRate < 0 ? PriceDirection.down : PriceDirection.flat);
    final color = directionColor(dir);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$rank. $name',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(Formatters.signedPercent(changeRate),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _Collecting extends StatelessWidget {
  const _Collecting();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('등락률 집계 중…',
          style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
    );
  }
}
