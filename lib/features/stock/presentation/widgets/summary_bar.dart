import 'package:flutter/material.dart';

import '../../application/stock_controller.dart';
import '../../application/summary_state.dart';
import '../../domain/entities/connection_status.dart';
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
            if (summary.connection.hasIssue)
              _ConnectionBanner(status: summary.connection),
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

/// 연결 상태 배너. 두 실패 모드를 다른 색/문구로 구분한다.
/// - unstable(주황): 에러 이벤트 발생, 안정 구간 확보되면 자동 복구
/// - stalled(빨강): 일정 시간 배치 미수신(조용한 정지) → 더 강한 경고
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final stalled = status.isStalled;
    final bg = stalled ? const Color(0xFFFDECEA) : const Color(0xFFFFF3E0);
    final fg = stalled ? const Color(0xFFC62828) : const Color(0xFFE65100);
    final icon = stalled ? Icons.cloud_off : Icons.wifi_tethering_error;
    final text = stalled ? '실시간 수신 지연 · 재연결 대기 중' : '연결 불안정 · 자동 복구 중';

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: fg)),
        ],
      ),
    );
  }
}
