import 'trade_status.dart';

/// 한 종목의 현재 시세 상태(불변 값 객체).
///
/// seed의 raw `QuoteTick` 을 도메인으로 변환하며, 파생값(등락률/등락폭)을 함께
/// 계산해 담는다. 프레젠테이션은 이 값만 소비하고 raw tick은 알지 못한다.
///
/// [timestampMs] 는 **정합성(역순 tick 폐기)** 판단에 쓰인다. 도착 순서가 아니라
/// 이 값이 이벤트의 실제 시간 순서이므로, 더 큰 timestampMs 만 반영해야 한다.
class StockQuote {
  const StockQuote({
    required this.code,
    required this.price,
    required this.dayVolume,
    required this.status,
    required this.timestampMs,
    required this.changeRate,
    required this.changeAmount,
  });

  final String code;

  /// 현재가(원). [status] 가 halted면 직전 체결가로 고정.
  final double price;

  /// 당일 누적 거래량.
  final int dayVolume;

  final TradeStatus status;

  /// 이벤트의 실제 시각(epoch ms). 정합성 판단 기준.
  final int timestampMs;

  /// 전일 대비 등락률(%).
  final double changeRate;

  /// 전일 대비 등락폭(원).
  final double changeAmount;

  bool get isHalted => status.isHalted;
  bool get isUp => changeAmount > 0;
  bool get isDown => changeAmount < 0;
}
