/// 당일(세션) 기준 시가/고가/저가 파생값.
///
/// feed는 이 값을 직접 주지 않는다. tick 흐름에서 누적 계산한다.
/// - [open] : 세션 시작가 (스냅샷 price 또는 첫 tick — 설계상 스냅샷 price 사용)
/// - [high] : 세션 running max
/// - [low]  : 세션 running min
class Ohlc {
  const Ohlc({
    required this.open,
    required this.high,
    required this.low,
  });

  final double open;
  final double high;
  final double low;

  Ohlc merge(double price) => Ohlc(
        open: open,
        high: price > high ? price : high,
        low: price < low ? price : low,
      );

  static Ohlc seed(double price) => Ohlc(open: price, high: price, low: price);
}
