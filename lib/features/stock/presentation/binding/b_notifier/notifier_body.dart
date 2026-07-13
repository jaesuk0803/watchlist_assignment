import 'package:flutter/material.dart';

import '../../../application/stock_controller.dart';
import '../../view_models/quote_vm.dart';
import '../../widgets/quote_row.dart';

/// 후보 B — 행별 ValueNotifier(채택 후보).
///
/// 종목당 `ValueNotifier<QuoteVM>` 를 하나씩 두고, 각 행은 자기 종목의 notifier만
/// `ValueListenableBuilder` 로 구독한다. 프레임 flush 때 **dirty 종목의 notifier만**
/// 값을 바꾸므로 그 행만 rebuild된다(잎사귀 단위). `RepaintBoundary` 로 페인트도
/// 행 단위 격리.
class NotifierBody extends StatefulWidget {
  const NotifierBody({
    super.key,
    required this.controller,
    required this.codes,
    required this.onTapRow,
  });

  final StockController controller;
  final List<String> codes;
  final void Function(String code) onTapRow;

  @override
  State<NotifierBody> createState() => _NotifierBodyState();
}

class _NotifierBodyState extends State<NotifierBody> {
  late final Map<String, ValueNotifier<QuoteVM>> _notifiers;

  @override
  void initState() {
    super.initState();
    final store = widget.controller.store;
    // 종목당 1개 notifier(전 종목). 목록 필터가 바뀌어도 재생성 불필요.
    _notifiers = {
      for (final code in store.orderedCodes)
        code: ValueNotifier<QuoteVM>(
          QuoteVM.from(store.metaOf(code), store.quoteOf(code)),
        ),
    };
    widget.controller.addFrameListener(_onFrame);
  }

  void _onFrame(Set<String> dirty) {
    final store = widget.controller.store;
    for (final code in dirty) {
      final notifier = _notifiers[code];
      if (notifier == null) continue; // 바뀐 행만 갱신
      notifier.value = QuoteVM.from(store.metaOf(code), store.quoteOf(code));
    }
  }

  @override
  void dispose() {
    widget.controller.removeFrameListener(_onFrame);
    for (final n in _notifiers.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemExtent: QuoteRow.height,
      itemCount: widget.codes.length,
      itemBuilder: (context, i) {
        final code = widget.codes[i];
        return RepaintBoundary(
          child: ValueListenableBuilder<QuoteVM>(
            valueListenable: _notifiers[code]!,
            builder: (context, vm, _) =>
                QuoteRow(vm: vm, onTap: () => widget.onTapRow(code)),
          ),
        );
      },
    );
  }
}
