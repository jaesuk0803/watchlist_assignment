import 'package:flutter/material.dart';

import '../../../application/stock_controller.dart';
import '../../view_models/quote_vm.dart';
import '../../widgets/quote_row.dart';

/// 후보 A — baseline(의도적으로 순진한 구현).
///
/// 프레임마다 `setState()` 로 목록 전체를 rebuild하고, 행에 `RepaintBoundary` 도
/// 두지 않는다. PERF.md의 before(기준선). dirty set을 무시한다.
class SetStateBody extends StatefulWidget {
  const SetStateBody({
    super.key,
    required this.controller,
    required this.codes,
    required this.onTapRow,
  });

  final StockController controller;
  final List<String> codes;
  final void Function(String code) onTapRow;

  @override
  State<SetStateBody> createState() => _SetStateBodyState();
}

class _SetStateBodyState extends State<SetStateBody> {
  void _onFrame(Set<String> dirty) {
    // baseline: dirty를 쓰지 않고 무조건 전체 rebuild.
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addFrameListener(_onFrame);
  }

  @override
  void dispose() {
    widget.controller.removeFrameListener(_onFrame);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.controller.store;
    return ListView.builder(
      itemExtent: QuoteRow.height,
      itemCount: widget.codes.length,
      itemBuilder: (context, i) {
        final code = widget.codes[i];
        final vm = QuoteVM.from(store.metaOf(code), store.quoteOf(code));
        // baseline: RepaintBoundary 없음.
        return QuoteRow(vm: vm, onTap: () => widget.onTapRow(code));
      },
    );
  }
}
