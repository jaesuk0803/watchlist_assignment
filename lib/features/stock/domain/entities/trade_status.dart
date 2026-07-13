/// 도메인 전용 거래 상태.
///
/// seed의 [QuoteStatus] 를 도메인 enum으로 매핑한다.
/// - [active]  : 정상 거래
/// - [halted]  : 거래정지(가격 고정)
enum TradeStatus {
  active,
  halted;

  bool get isHalted => this == TradeStatus.halted;
}
