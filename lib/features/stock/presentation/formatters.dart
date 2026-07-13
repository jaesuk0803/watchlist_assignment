/// 표시용 숫자 포맷 유틸(외부 의존성 없이 간단 구현).
class Formatters {
  const Formatters._();

  /// 천 단위 구분 정수 문자열. 예: 1234567 → "1,234,567"
  static String thousands(num value) {
    final isNegative = value < 0;
    final digits = value.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return isNegative ? '-${buffer.toString()}' : buffer.toString();
  }

  /// 등락률(%) 부호 포함 1자리. 예: 2.13 → "+2.13%", -0.5 → "-0.50%"
  static String signedPercent(double value) {
    final sign = value > 0 ? '+' : (value < 0 ? '' : '');
    return '$sign${value.toStringAsFixed(2)}%';
  }

  /// 등락폭 부호 포함. 예: 250 → "+250", -100 → "-100"
  static String signedAmount(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${thousands(value)}';
  }

  /// 큰 금액을 조/억 단위로 축약. 예: 1.23e14 → "123.0조"
  static String marketCap(double value) {
    const jo = 1e12;
    const eok = 1e8;
    if (value >= jo) return '${(value / jo).toStringAsFixed(1)}조';
    if (value >= eok) return '${(value / eok).toStringAsFixed(1)}억';
    return thousands(value);
  }
}
