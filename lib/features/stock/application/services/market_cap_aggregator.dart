/// 시가총액 합계를 **증분(델타 누적)** 으로 유지한다.
///
/// 매 tick마다 전 종목을 다시 곱하고 더하지 않는다. 종목별 직전 기여분
/// (현재가 × 상장주식수)을 기억해두고, 값이 바뀔 때 (새 기여 − 옛 기여)만
/// 합계에 가감한다. → 갱신당 O(1).
///
/// 집계 범위는 **전체 유니버스**다(필터와 무관). 요약의 시총 합계는 시장 전체
/// 지표라는 판단(DESIGN.md). 표시 종목 수만 필터 기준으로 센다.
class MarketCapAggregator {
  final Map<String, double> _contribution = {};
  double _total = 0;

  double get total => _total;

  /// 초기 시드(1회). 종목의 첫 기여분을 등록한다.
  void seed(String code, double price, int listedShares) {
    final contribution = price * listedShares;
    _contribution[code] = contribution;
    _total += contribution;
  }

  /// 가격 변동 반영. 델타만 합계에 가감한다.
  void update(String code, double price, int listedShares) {
    final contribution = price * listedShares;
    final previous = _contribution[code] ?? 0;
    _total += contribution - previous;
    _contribution[code] = contribution;
  }
}
