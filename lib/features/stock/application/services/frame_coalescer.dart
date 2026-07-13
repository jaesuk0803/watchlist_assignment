import 'package:flutter/scheduler.dart';

/// 프레임 정렬 coalescer.
///
/// tick은 수시로(초당 수천) 들어와 dirty에 쌓이지만, UI 반영은 **프레임당 1회**로
/// 몰아서(coalesce) 한다. `Ticker` 를 써서 실제 화면 갱신 주기(vsync)에 정렬하므로
/// 60Hz면 약 16.6ms, 120Hz면 약 8.3ms 마다 자동으로 flush가 호출당한다.
///
/// 프레임당 1회면 최대 stale은 약 1프레임(≪ 200ms 신선도 제약)이고, 같은 종목이
/// 프레임 내 여러 번 바뀌어도 dirty set 특성상 rebuild는 1회로 합쳐진다.
///
/// 벤치마크/테스트는 벽시계에 의존하지 않도록 이 coalescer를 쓰지 않고
/// 컨트롤러의 수동 flush를 호출한다.
class FrameCoalescer {
  FrameCoalescer(this._onFrame);

  final void Function() _onFrame;
  Ticker? _ticker;

  void attach(TickerProvider vsync) {
    _ticker?.dispose();
    _ticker = vsync.createTicker((_) => _onFrame());
    _ticker!.start();
  }

  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }
}
