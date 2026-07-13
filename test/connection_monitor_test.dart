import 'package:flutter_test/flutter_test.dart';
import 'package:watchlist_assignment/features/stock/application/services/connection_monitor.dart';
import 'package:watchlist_assignment/features/stock/domain/entities/connection_status.dart';

void main() {
  test('명시적 에러는 즉시 unstable로 전환된다', () {
    final m = ConnectionMonitor(stallFrames: 100, recoveryBatches: 3);
    m.onBatch(); // prime → live
    expect(m.onError(), ConnectionStatus.unstable);
    expect(m.status, ConnectionStatus.unstable);
  });

  test('디바운스 복구: 연속 정상 배치 N건이 쌓여야 live로 복구된다', () {
    final m = ConnectionMonitor(stallFrames: 100, recoveryBatches: 3);
    m.onBatch(); // prime
    m.onError(); // unstable
    expect(m.onBatch(), isNull); // 1건 — 아직
    expect(m.onBatch(), isNull); // 2건 — 아직
    expect(m.onBatch(), ConnectionStatus.live); // 3건 — 복구
  });

  test('조용한 정지: 배치 없이 프레임이 임계만큼 지나면 stalled', () {
    final m = ConnectionMonitor(stallFrames: 5, recoveryBatches: 3);
    m.onBatch(); // prime
    for (var i = 0; i < 4; i++) {
      expect(m.onFrame(), isNull); // 1..4 프레임 < 5
    }
    expect(m.onFrame(), ConnectionStatus.stalled); // 5 프레임 → 정지
  });

  test('정지 후 배치 재개도 디바운스 복구를 거친다', () {
    final m = ConnectionMonitor(stallFrames: 5, recoveryBatches: 3);
    m.onBatch();
    for (var i = 0; i < 5; i++) {
      m.onFrame();
    }
    expect(m.status, ConnectionStatus.stalled);
    expect(m.onBatch(), isNull); // 1
    expect(m.onBatch(), isNull); // 2
    expect(m.onBatch(), ConnectionStatus.live); // 3 → 복구
  });

  test('복구 직전 에러가 오면 복구 카운터가 리셋된다(flapping 방지)', () {
    final m = ConnectionMonitor(stallFrames: 100, recoveryBatches: 3);
    m.onBatch();
    m.onError(); // unstable
    m.onBatch(); // 1
    m.onBatch(); // 2 (곧 복구될 뻔)
    expect(m.onError(), isNull); // 이미 unstable, 단 카운터는 0으로 리셋
    expect(m.onBatch(), isNull); // 1
    expect(m.onBatch(), isNull); // 2
    expect(m.onBatch(), ConnectionStatus.live); // 3 → 그제야 복구
  });

  test('첫 배치 전 프레임 틱은 상태를 바꾸지 않는다', () {
    final m = ConnectionMonitor(stallFrames: 2, recoveryBatches: 3);
    expect(m.onFrame(), isNull);
    expect(m.onFrame(), isNull);
    expect(m.status, ConnectionStatus.live);
  });
}
