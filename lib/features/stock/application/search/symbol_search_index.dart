import '../../domain/entities/stock_meta.dart';
import 'chosung.dart';

/// 종목 검색 인덱스.
///
/// 시작 시 **1회** 구축한다(종목명은 세션 동안 불변이므로). tick 흐름과 무관하며,
/// 필터는 keystroke 시(debounce 후)에만 수행되고 매 tick 재계산하지 않는다.
///
/// 지원:
/// - 초성 검색: `ㄱㅇ` → 초성열 'ㄱㅇ...' 포함
/// - 완성형 부분일치: `전자` → 종목명 포함
/// - 종목코드 부분일치: `000590` → 코드 포함
class SymbolSearchIndex {
  SymbolSearchIndex(List<StockMeta> metas)
      : _entries = List.unmodifiable(
          metas.map(
            (m) => _IndexEntry(
              code: m.code,
              name: m.name,
              choseong: Chosung.extract(m.name),
            ),
          ),
        );

  final List<_IndexEntry> _entries;

  /// [query] 에 매칭되는 종목코드 집합. 빈 쿼리는 전체를 뜻하므로 null 반환
  /// (호출부에서 "필터 없음"으로 처리).
  Set<String>? match(String query) {
    final q = query.trim();
    if (q.isEmpty) return null;

    final result = <String>{};
    if (Chosung.isChoseongQuery(q)) {
      for (final e in _entries) {
        if (e.choseong.contains(q)) result.add(e.code);
      }
    } else {
      for (final e in _entries) {
        if (e.name.contains(q) || e.code.contains(q)) result.add(e.code);
      }
    }
    return result;
  }
}

class _IndexEntry {
  const _IndexEntry({
    required this.code,
    required this.name,
    required this.choseong,
  });

  final String code;
  final String name;
  final String choseong;
}
