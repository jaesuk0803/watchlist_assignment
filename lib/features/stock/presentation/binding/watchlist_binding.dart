import 'package:flutter/widgets.dart';

import '../../../../app/candidate.dart';
import '../../application/stock_controller.dart';
import 'a_setstate/setstate_body.dart';
import 'b_notifier/notifier_body.dart';
import 'c_riverpod/riverpod_body.dart';

/// 목록 본문 전파 전략(A/B/C 교체 지점).
///
/// domain/data/application 은 1벌 그대로 두고, 이 계층만 후보별로 갈아끼워
/// 동일 조건에서 성능을 비교한다.
abstract class WatchlistBinding {
  /// 목록 본문 위젯. [visibleCodes] 는 필터 결과(구조 변경 시에만 새로 전달).
  /// [onTapRow] 는 행 탭 시 상세로 이동하는 콜백.
  Widget buildBody(
    StockController controller,
    List<String> visibleCodes,
    void Function(String code) onTapRow,
  );

  static WatchlistBinding forCandidate(Candidate candidate) =>
      switch (candidate) {
        Candidate.a => const _SetStateBinding(),
        Candidate.b => const _NotifierBinding(),
        Candidate.c => const _RiverpodBinding(),
      };
}

class _SetStateBinding implements WatchlistBinding {
  const _SetStateBinding();

  @override
  Widget buildBody(controller, visibleCodes, onTapRow) => SetStateBody(
        controller: controller,
        codes: visibleCodes,
        onTapRow: onTapRow,
      );
}

class _NotifierBinding implements WatchlistBinding {
  const _NotifierBinding();

  @override
  Widget buildBody(controller, visibleCodes, onTapRow) => NotifierBody(
        controller: controller,
        codes: visibleCodes,
        onTapRow: onTapRow,
      );
}

class _RiverpodBinding implements WatchlistBinding {
  const _RiverpodBinding();

  @override
  Widget buildBody(controller, visibleCodes, onTapRow) => RiverpodBody(
        controller: controller,
        codes: visibleCodes,
        onTapRow: onTapRow,
      );
}
