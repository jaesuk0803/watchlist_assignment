import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../application/stock_controller.dart';
import '../../../domain/entities/stock_quote.dart';

/// C 후보용 컨트롤러 주입(ProviderScope override로 실제 인스턴스 주입).
final controllerProvider = Provider<StockController>(
  (_) => throw UnimplementedError('override in ProviderScope'),
);

/// 종목별 시세 provider(family). 초기값은 store에서 시드.
/// flush 콜백에서 dirty 종목의 state만 갱신 → 그 provider를 watch하던 행만 rebuild.
final rowQuoteProvider = StateProvider.family<StockQuote, String>(
  (ref, code) => ref.read(controllerProvider).store.quoteOf(code),
);
