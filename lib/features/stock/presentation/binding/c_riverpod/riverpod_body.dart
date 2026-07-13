import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/stock_controller.dart';
import '../../view_models/quote_vm.dart';
import '../../widgets/quote_row.dart';
import 'providers.dart';

/// 후보 C — Riverpod family + select.
///
/// 개념은 B와 동일(잎사귀 단위, dirty만 갱신)하나, notifier 대신 provider/ref
/// 그래프로 의존을 추적한다. flush에서 dirty 종목의 provider state만 갱신하면
/// Riverpod이 그 provider를 watch하던 Consumer만 rebuild한다.
class RiverpodBody extends StatelessWidget {
  const RiverpodBody({
    super.key,
    required this.controller,
    required this.codes,
    required this.onTapRow,
  });

  final StockController controller;
  final List<String> codes;
  final void Function(String code) onTapRow;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [controllerProvider.overrideWithValue(controller)],
      child: _RiverpodList(
        controller: controller,
        codes: codes,
        onTapRow: onTapRow,
      ),
    );
  }
}

class _RiverpodList extends ConsumerStatefulWidget {
  const _RiverpodList({
    required this.controller,
    required this.codes,
    required this.onTapRow,
  });

  final StockController controller;
  final List<String> codes;
  final void Function(String code) onTapRow;

  @override
  ConsumerState<_RiverpodList> createState() => _RiverpodListState();
}

class _RiverpodListState extends ConsumerState<_RiverpodList> {
  @override
  void initState() {
    super.initState();
    widget.controller.addFrameListener(_onFrame);
  }

  void _onFrame(Set<String> dirty) {
    final store = widget.controller.store;
    for (final code in dirty) {
      ref.read(rowQuoteProvider(code).notifier).state = store.quoteOf(code);
    }
  }

  @override
  void dispose() {
    widget.controller.removeFrameListener(_onFrame);
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
          child: Consumer(
            builder: (context, ref, _) {
              final quote = ref.watch(rowQuoteProvider(code));
              final meta = widget.controller.store.metaOf(code);
              return QuoteRow(
                vm: QuoteVM.from(meta, quote),
                onTap: () => widget.onTapRow(code),
              );
            },
          ),
        );
      },
    );
  }
}
