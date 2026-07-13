/// 시세 스트림의 연결 상태.
///
/// feed의 일시적 스트림 에러(transientError)를 UI로 표현하기 위한 도메인 상태.
/// 에러가 와도 구독은 유지되고 다음 배치로 복구되므로, [unstable] 은 잠깐
/// 표시된 뒤 [live] 로 되돌아간다.
enum ConnectionStatus {
  /// 정상 수신 중.
  live,

  /// 일시적 오류 발생(구독 유지, 곧 복구).
  unstable;

  bool get isUnstable => this == ConnectionStatus.unstable;
}
