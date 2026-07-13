import '../../domain/entities/stock_meta.dart';
import '../../domain/entities/stock_quote.dart';

/// 방향(등락 색상 결정용).
enum PriceDirection { up, down, flat }

/// 행 렌더링에 필요한 불변 뷰모델.
///
/// 도메인(meta + quote)에서 프레젠테이션 표시값만 추린다. 위젯은 이 값만 받으므로
/// 전파 방식(A/B/C)과 무관하게 동일한 행 UI를 공유한다.
class QuoteVM {
  const QuoteVM({
    required this.code,
    required this.name,
    required this.price,
    required this.changeRate,
    required this.changeAmount,
    required this.dayVolume,
    required this.isHalted,
    required this.direction,
  });

  final String code;
  final String name;
  final double price;
  final double changeRate;
  final double changeAmount;
  final int dayVolume;
  final bool isHalted;
  final PriceDirection direction;

  factory QuoteVM.from(StockMeta meta, StockQuote quote) {
    final PriceDirection dir;
    if (quote.changeAmount > 0) {
      dir = PriceDirection.up;
    } else if (quote.changeAmount < 0) {
      dir = PriceDirection.down;
    } else {
      dir = PriceDirection.flat;
    }
    return QuoteVM(
      code: meta.code,
      name: meta.name,
      price: quote.price,
      changeRate: quote.changeRate,
      changeAmount: quote.changeAmount,
      dayVolume: quote.dayVolume,
      isHalted: quote.isHalted,
      direction: dir,
    );
  }
}
