import 'package:flutter/material.dart';

import '../../application/stock_controller.dart';
import '../../application/summary_state.dart';
import '../formatters.dart';

/// 요약 영역: 표시 종목 수 + 시총 합계 + 연결 상태 배너.
///
/// `controller.summary`(프레임당 갱신) 하나만 구독하므로 목록 2,000행과 무관하게
/// 이 작은 위젯만 rebuild된다.
class SummaryBar extends StatelessWidget {
  const SummaryBar({super.key, required this.controller});

  final StockController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SummaryState>(
      valueListenable: controller.summary,
      builder: (context, summary, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary.connection.isUnstable) const _UnstableBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _Metric(
                    label: '표시 종목',
                    value: '${Formatters.thousands(summary.displayedCount)}개',
                  ),
                  const SizedBox(width: 24),
                  _Metric(
                    label: '시가총액 합계',
                    value: Formatters.marketCap(summary.totalMarketCap),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _UnstableBanner extends StatelessWidget {
  const _UnstableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: const Row(
        children: [
          Icon(Icons.wifi_tethering_error, size: 14, color: Color(0xFFE65100)),
          SizedBox(width: 6),
          Text('연결 불안정 · 자동 복구 중',
              style: TextStyle(fontSize: 12, color: Color(0xFFE65100))),
        ],
      ),
    );
  }
}
