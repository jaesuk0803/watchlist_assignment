import '../../domain/entities/ohlc.dart';
import '../../domain/entities/stock_meta.dart';
import '../../domain/entities/stock_quote.dart';
import '../services/market_cap_aggregator.dart';
import '../services/top_movers_tracker.dart';

/// 단일 시세 저장소(SSOT).
///
/// 모든 화면(목록/Top-20/상세)이 참조하는 유일한 상태 원본. 검증된 시세 배치를
/// 반영하면서 다음을 함께 유지한다:
/// - 종목별 현재 시세(`quote`)
/// - 종목별 당일 시/고/저(`ohlc`) — 상세 화면용, running max/min 누적
/// - **dirty set**: 이번 프레임에 바뀐 종목코드(프레임당 1회 flush)
/// - 증분 집계: 시총 합계(aggregator), 등락률 Top-20(tracker)
///
/// 정합성(역순 tick 폐기)은 이미 data 계층에서 끝났으므로 여기선 신경쓰지 않는다.
class QuoteStore {
  final Map<String, StockMeta> _metaByCode = {};
  final Map<String, StockQuote> _quoteByCode = {};
  final Map<String, Ohlc> _ohlcByCode = {};

  /// 가나다(종목명)순 정렬 코드. 동점이면 코드순. 목록 기본 표시 순서(고정).
  List<String> _orderedCodes = const [];

  final Set<String> _dirty = <String>{};

  final MarketCapAggregator _marketCap = MarketCapAggregator();
  final TopMoversTracker _topMovers = TopMoversTracker();

  List<String> get orderedCodes => _orderedCodes;
  int get symbolCount => _orderedCodes.length;
  double get totalMarketCap => _marketCap.total;
  List<String> topMoverCodes() => _topMovers.top();

  StockMeta metaOf(String code) => _metaByCode[code]!;
  StockQuote quoteOf(String code) => _quoteByCode[code]!;
  Ohlc ohlcOf(String code) => _ohlcByCode[code]!;

  /// 시작 시 1회 초기화. 메타/초기시세를 세팅하고 집계를 시드한다.
  void initialize(List<StockMeta> metas, List<StockQuote> initialQuotes) {
    for (final m in metas) {
      _metaByCode[m.code] = m;
    }
    final quoteByCode = {for (final q in initialQuotes) q.code: q};
    for (final m in metas) {
      final q = quoteByCode[m.code]!;
      _quoteByCode[m.code] = q;
      _ohlcByCode[m.code] = Ohlc.seed(q.price);
      _marketCap.seed(m.code, q.price, m.listedShares);
      _topMovers.seed(m.code, q.changeRate);
    }
    // 가나다순 고정 정렬(이름 중복 많음 → 코드순 tie-break).
    final codes = metas.map((m) => m.code).toList();
    codes.sort((a, b) {
      final byName = _metaByCode[a]!.name.compareTo(_metaByCode[b]!.name);
      if (byName != 0) return byName;
      return a.compareTo(b);
    });
    _orderedCodes = List.unmodifiable(codes);
  }

  /// 검증된 시세 배치 반영. dirty 누적 + 증분 집계 갱신.
  void applyBatch(List<StockQuote> quotes) {
    for (final q in quotes) {
      final meta = _metaByCode[q.code];
      if (meta == null) continue;
      _quoteByCode[q.code] = q;
      // 정지 구간은 가격 고정이라 high/low에 영향 없음(merge가 자연히 무시).
      _ohlcByCode[q.code] = _ohlcByCode[q.code]!.merge(q.price);
      _marketCap.update(q.code, q.price, meta.listedShares);
      _topMovers.update(q.code, q.changeRate);
      _dirty.add(q.code);
    }
  }

  /// 이번 프레임의 dirty 집합을 넘기고 비운다(프레임당 1회 호출).
  Set<String> takeDirty() {
    if (_dirty.isEmpty) return const <String>{};
    final snapshot = Set<String>.from(_dirty);
    _dirty.clear();
    return snapshot;
  }

  bool get hasDirty => _dirty.isNotEmpty;
}
