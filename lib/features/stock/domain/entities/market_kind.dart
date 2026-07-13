/// 도메인 전용 시장 구분.
///
/// seed의 [MarketType] 을 그대로 쓰지 않고 도메인 enum으로 매핑하여
/// seed(원시 계층)와 도메인/프레젠테이션의 결합을 끊는다(부패방지층 경계).
enum MarketKind {
  kospi,
  kosdaq;

  String get label => switch (this) {
        MarketKind.kospi => 'KOSPI',
        MarketKind.kosdaq => 'KOSDAQ',
      };
}
