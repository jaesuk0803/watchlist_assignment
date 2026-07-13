import '../../domain/entities/connection_status.dart';

/// 연결 상태 판정의 **순수 로직**. 타이머도 벽시계도 쓰지 않는다.
///
/// 두 실패 모드를 서로 다른 "카운트"로 다룬다.
///
/// 1. **정지 감지(워치독)** — `마지막 배치 이후 경과 프레임 수`.
///    데이터가 *안 오는 것*은 이벤트가 아니라 이벤트 기반으론 감지할 수 없다.
///    그래서 주기적으로 깨어나 확인하는 무언가가 필요한데, Flutter는 이미
///    vsync 프레임 루프라는 하트비트가 있다. 별도 [Timer] 를 만들지 않고 그
///    프레임 틱([onFrame])을 재사용해, `프레임 수 >= [stallFrames]` 이면
///    [ConnectionStatus.stalled] 로 본다. (60fps에서 90프레임 ≈ 1.5초)
///
/// 2. **디바운스 복구** — `연속 정상 배치 수`.
///    에러 직후 배치 1건으로 곧장 복구하지 않고, 에러 이후 [recoveryBatches] 건이
///    끊김 없이 흐른 뒤에야 [ConnectionStatus.live] 로 되돌린다. 서킷 브레이커의
///    successThreshold(연속 성공 N회 → 닫힘)와 같은 방식으로, flapping(깜빡임)에
///    배너가 요동치는 것을 막는다.
///
/// 시간/타이머 대신 프레임·배치 카운트만 쓰므로, 테스트는 [onBatch]/[onError]/
/// [onFrame] 을 원하는 횟수만큼 호출하는 것만으로 결정론적으로 검증된다.
class ConnectionMonitor {
  ConnectionMonitor({
    this.stallFrames = 90,
    this.recoveryBatches = 60,
  });

  /// 이 프레임 수 이상 배치가 없으면 정지로 판정.
  final int stallFrames;

  /// 이 수만큼 연속 정상 배치가 흘러야 복구.
  final int recoveryBatches;

  int _framesSinceBatch = 0;
  int _goodStreak = 0;
  bool _primed = false;
  ConnectionStatus _status = ConnectionStatus.live;

  ConnectionStatus get status => _status;

  /// 배치 도착(내용이 비어도 "스트림이 살아있다"는 신호). 상태 변화 시 반환.
  ConnectionStatus? onBatch() {
    _framesSinceBatch = 0;
    _primed = true;
    _goodStreak++;
    return _reevaluate();
  }

  /// 명시적 스트림 에러 → 즉시 불안정 + 복구 카운터 리셋. 상태 변화 시 반환.
  ConnectionStatus? onError() {
    _goodStreak = 0;
    return _transition(ConnectionStatus.unstable);
  }

  /// 프레임마다 1회. 기존 프레임 루프를 재사용하므로 별도 타이머가 없다.
  ConnectionStatus? onFrame() {
    if (!_primed) return null;
    _framesSinceBatch++;
    return _reevaluate();
  }

  ConnectionStatus? _reevaluate() {
    if (!_primed) return null;
    // 1) 조용한 정지: 마지막 배치 이후 경과 프레임이 임계 초과.
    if (_framesSinceBatch >= stallFrames) {
      return _transition(ConnectionStatus.stalled);
    }
    // 2) 배치가 흐르는 중. 비정상 상태였다면 연속 정상 배치가 쌓인 뒤 복구.
    if (_status != ConnectionStatus.live && _goodStreak >= recoveryBatches) {
      return _transition(ConnectionStatus.live);
    }
    return null;
  }

  ConnectionStatus? _transition(ConnectionStatus next) {
    if (_status == next) return null;
    _status = next;
    // 비정상으로 진입하면 복구 카운터를 리셋해, 이후 연속 정상 배치를 새로 센다.
    if (next != ConnectionStatus.live) _goodStreak = 0;
    return next;
  }
}
