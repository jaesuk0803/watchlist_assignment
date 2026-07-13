import 'dart:collection';

/// 등락률 상위 N(기본 20)을 **매 tick 전체 재정렬 없이** 유지한다.
///
/// 구현: `SplayTreeSet` 을 (등락률 내림차순, 동점이면 코드 오름차순) 정렬로 유지.
/// 종목의 등락률이 바뀌면 옛 항목 제거 + 새 항목 삽입 → 각 O(log n).
/// 상위 N 조회는 앞에서 N개 순회 → O(N). 전체 정렬 O(n log n)를 피한다.
///
/// **결정론적 tie-break(코드순)** 로 초기(등락률 전부 0%)와 실행 중 동점에서도
/// 순위가 흔들리지 않는다 → 벤치마크 재현성 확보.
class TopMoversTracker {
  TopMoversTracker({this.limit = 20});

  final int limit;

  final Map<String, _Rank> _byCode = {};
  final SplayTreeSet<_Rank> _sorted = SplayTreeSet<_Rank>(_compare);

  static int _compare(_Rank a, _Rank b) {
    final byRate = b.rate.compareTo(a.rate); // 등락률 내림차순
    if (byRate != 0) return byRate;
    return a.code.compareTo(b.code); // 동점 → 코드 오름차순
  }

  void seed(String code, double rate) => update(code, rate);

  /// 종목의 등락률 갱신. 옛 항목 제거 후 새 항목 삽입.
  void update(String code, double rate) {
    final old = _byCode[code];
    if (old != null) _sorted.remove(old);
    final rank = _Rank(code, rate);
    _byCode[code] = rank;
    _sorted.add(rank);
  }

  /// 현재 상위 [limit] 종목코드(등락률 내림차순).
  List<String> top() {
    final result = <String>[];
    for (final rank in _sorted) {
      result.add(rank.code);
      if (result.length >= limit) break;
    }
    return result;
  }
}

class _Rank {
  const _Rank(this.code, this.rate);

  final String code;
  final double rate;
}
