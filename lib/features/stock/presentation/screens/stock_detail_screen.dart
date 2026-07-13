import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../application/stock_controller.dart';
import '../../domain/entities/stock_quote.dart';
import '../formatters.dart';
import '../view_models/quote_vm.dart';
import '../widgets/quote_row.dart';
import '../widgets/sparkline.dart';

/// 화면 2 — 종목 상세.
///
/// 동일 feed에서 실시간 갱신되지만, **자체 Ticker** 로 store를 읽어 갱신하므로
/// 목록의 프레임 리스너와 독립적이다(목록은 pause되어 갱신 비용이 멈춤).
/// 스파크라인은 고정 길이 링버퍼로 최근 N개 체결가만 유지한다.
class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({
    super.key,
    required this.controller,
    required this.code,
  });

  final StockController controller;
  final String code;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxPoints = 60;

  late final Ticker _ticker;
  final List<double> _sparkPoints = [];
  int _lastTimestampMs = -1;
  late StockQuote _quote;

  @override
  void initState() {
    super.initState();
    _quote = widget.controller.store.quoteOf(widget.code);
    _sparkPoints.add(_quote.price);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    final latest = widget.controller.store.quoteOf(widget.code);
    // 새 tick(시각 변화)일 때만 반영 → 불필요한 rebuild/버퍼 증가 방지.
    if (latest.timestampMs == _lastTimestampMs) return;
    _lastTimestampMs = latest.timestampMs;
    setState(() {
      _quote = latest;
      _sparkPoints.add(latest.price);
      if (_sparkPoints.length > _maxPoints) {
        _sparkPoints.removeAt(0); // 링버퍼: 최근 N개만 유지
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.controller.store.metaOf(widget.code);
    final ohlc = widget.controller.store.ohlcOf(widget.code);
    final vm = QuoteVM.from(meta, _quote);
    final color = directionColor(vm.direction);

    return Scaffold(
      appBar: AppBar(title: Text(meta.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('${meta.name} ',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              Text(meta.code,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF9E9E9E))),
              const Spacer(),
              if (vm.isHalted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('거래정지',
                      style: TextStyle(fontSize: 12, color: Color(0xFF616161))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Formatters.thousands(vm.price),
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: vm.isHalted ? const Color(0xFF9E9E9E) : color),
          ),
          const SizedBox(height: 4),
          Text(
            '${Formatters.signedAmount(vm.changeAmount)}  (${Formatters.signedPercent(vm.changeRate)})',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 24),
          Sparkline(points: List.of(_sparkPoints), color: color),
          const SizedBox(height: 24),
          _OhlcRow(
            open: ohlc.open,
            high: ohlc.high,
            low: ohlc.low,
          ),
          const SizedBox(height: 16),
          _DetailMetric(
              label: '당일 거래량', value: Formatters.thousands(vm.dayVolume)),
          _DetailMetric(label: '시장', value: meta.market.label),
          _DetailMetric(
              label: '전일종가', value: Formatters.thousands(meta.previousClose)),
        ],
      ),
    );
  }
}

class _OhlcRow extends StatelessWidget {
  const _OhlcRow({required this.open, required this.high, required this.low});

  final double open;
  final double high;
  final double low;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _cell('시가', open, const Color(0xFF616161)),
        _cell('고가', high, const Color(0xFFD32F2F)),
        _cell('저가', low, const Color(0xFF1976D2)),
      ],
    );
  }

  Widget _cell(String label, double value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
        const SizedBox(height: 4),
        Text(Formatters.thousands(value),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF757575))),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
