/// 시세 스트림의 연결 상태.
///
/// 두 가지 서로 다른 실패 모드를 구분한다.
/// - [unstable]: feed가 **명시적 에러 이벤트**를 냈다(transientError). 구독은
///   유지되며, 안정 구간이 확보되면 [live] 로 복구된다(디바운스 복구).
/// - [stalled]: 에러도 없이 **일정 시간 배치 자체가 끊긴** 조용한 정지
///   (silent stall). 에러 이벤트로는 잡을 수 없어 워치독(하트비트)으로 감지한다.
enum ConnectionStatus {
  /// 정상 수신 중.
  live,

  /// 일시적 오류 발생(구독 유지, 안정되면 복구).
  unstable,

  /// 일정 시간 배치 미수신(조용한 정지). 워치독이 감지.
  stalled;

  bool get isLive => this == ConnectionStatus.live;
  bool get isUnstable => this == ConnectionStatus.unstable;
  bool get isStalled => this == ConnectionStatus.stalled;

  /// 사용자에게 안내가 필요한 비정상 상태(불안정 또는 정지).
  bool get hasIssue => this != ConnectionStatus.live;
}
