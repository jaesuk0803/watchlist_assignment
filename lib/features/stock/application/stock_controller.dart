import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../domain/entities/connection_status.dart';
import '../domain/entities/stock_quote.dart';
import '../domain/repositories/stock_repository.dart';
import 'search/symbol_search_index.dart';
import 'services/connection_monitor.dart';
import 'services/frame_coalescer.dart';
import 'store/quote_store.dart';
import 'summary_state.dart';

/// 애플리케이션 조율자.
///
/// repository(데이터) ↔ store(상태) ↔ presentation(전파 A/B/C)을 잇는다.
/// - feed 구독은 repository 한 곳(SSOT 단일 진입)
/// - 프레임마다 `_onFrame` 에서 dirty를 걷어 등록된 프레임 리스너(=binding)에 전달
/// - 요약/필터는 별도 [summary]/[filter] 노티파이어로 노출
///
/// 벤치마크/테스트는 [attachVsync] 대신 [flushFrame] 을 직접 호출해 결정론적으로
/// 프레임을 진행한다.
class StockController {
  StockController(this._repo, {this.naiveSummary = false});

  final StockRepository _repo;

  /// true면 요약(시총/Top-20)을 **매 프레임 전체 순회**로 재계산한다(baseline A용).
  /// false면 application의 증분 집계(O(1)/O(log n)) 결과를 사용한다(B/C, 채택).
  final bool naiveSummary;
  final QuoteStore store = QuoteStore();
  late final SymbolSearchIndex searchIndex;

  /// 요약 영역 상태(프레임당 갱신).
  final ValueNotifier<SummaryState> summary =
      ValueNotifier<SummaryState>(const SummaryState.empty());

  /// 현재 필터 결과(null = 전체). 목록 구조 변경 시에만 바뀜(매 tick 아님).
  final ValueNotifier<Set<String>?> filter = ValueNotifier<Set<String>?>(null);

  final List<void Function(Set<String>)> _frameListeners = [];
  bool _listenersPaused = false;

  FrameCoalescer? _coalescer;
  StreamSubscription? _batchSub;
  StreamSubscription? _errorSub;

  /// 연결 상태 판정(정지 감지·디바운스 복구) — 타이머 없이 프레임/배치 카운트로.
  final ConnectionMonitor _monitor = ConnectionMonitor();
  ConnectionStatus _connection = ConnectionStatus.live;
  bool _connectionDirty = false;

  /// 시작 시 1회. 유니버스 로드 + store 초기화 + 검색 인덱스 구축 + 구독 연결.
  void init() {
    final data = _repo.loadUniverse();
    store.initialize(data.metas, data.initialQuotes);
    searchIndex = SymbolSearchIndex(data.metas);
    _batchSub = _repo.quoteBatches().listen(_onBatch);
    _errorSub = _repo.errors().listen(_onError);
    _publishSummary();
  }

  void _onBatch(List<StockQuote> batch) {
    store.applyBatch(batch);
    _applyConnection(_monitor.onBatch());
  }

  void _onError(Object error) => _applyConnection(_monitor.onError());

  void _applyConnection(ConnectionStatus? next) {
    if (next == null) return;
    _connection = next;
    _connectionDirty = true;
  }

  /// 실시간(벽시계) 수신 시작. 프레임 정렬 flush를 붙인다.
  void attachVsync(TickerProvider vsync) {
    _coalescer = FrameCoalescer(_onFrame)..attach(vsync);
    _repo.start();
  }

  /// vsync를 제공한 위젯(화면)이 dispose될 때 Ticker를 함께 해제한다.
  /// (Ticker 수명은 vsync provider와 일치해야 함)
  void detachVsync() {
    _coalescer?.dispose();
    _coalescer = null;
  }

  /// 필터 아웃되지 않은(표시 대상) 종목코드. 필터 없으면 전체(가나다순).
  List<String> visibleCodes() {
    final f = filter.value;
    if (f == null) return store.orderedCodes;
    return store.orderedCodes.where(f.contains).toList(growable: false);
  }

  void addFrameListener(void Function(Set<String>) fn) =>
      _frameListeners.add(fn);
  void removeFrameListener(void Function(Set<String>) fn) =>
      _frameListeners.remove(fn);

  /// 목록이 상세에 가려질 때 목록 갱신 비용을 멈춘다(과제: 구독 수명 관리).
  void pauseFrameListeners() => _listenersPaused = true;
  void resumeFrameListeners() => _listenersPaused = false;

  void _onFrame() {
    // 프레임 하트비트 재사용: 마지막 배치 이후 경과 프레임으로 정지를 감지한다.
    _applyConnection(_monitor.onFrame());

    // 목록이 상세에 가려진 동안엔 dirty를 소비하지 않고 그대로 둔다.
    // (소비해버리면 복귀 시 그 사이 변경분이 유실되어 행이 stale해짐)
    // 상세는 자체 Ticker로 갱신하므로 목록 갱신 비용만 멈춘다.
    // 단, 연결 상태 변화는 가려진 중에도 요약에 반영해 둔다(복귀 시 정확).
    if (_listenersPaused) {
      if (_connectionDirty) {
        _publishSummary();
        _connectionDirty = false;
      }
      return;
    }

    final dirty = store.takeDirty();
    if (dirty.isNotEmpty) {
      for (final listener in _frameListeners) {
        listener(dirty);
      }
    }
    if (dirty.isNotEmpty || _connectionDirty) {
      _publishSummary();
      _connectionDirty = false;
    }
  }

  /// 결정론적 테스트/벤치용 수동 프레임 진행.
  void flushFrame() => _onFrame();

  void setQuery(String query) {
    filter.value = searchIndex.match(query);
    _publishSummary();
  }

  void _publishSummary() {
    summary.value = SummaryState(
      displayedCount: filter.value?.length ?? store.symbolCount,
      totalMarketCap:
          naiveSummary ? _marketCapNaive() : store.totalMarketCap,
      topMoverCodes:
          naiveSummary ? _topMoversNaive() : store.topMoverCodes(),
      connection: _connection,
    );
  }

  /// baseline: 매 호출마다 전 종목을 다시 곱해 합산 → O(n).
  double _marketCapNaive() {
    var sum = 0.0;
    for (final code in store.orderedCodes) {
      sum += store.quoteOf(code).price * store.metaOf(code).listedShares;
    }
    return sum;
  }

  /// baseline: 매 호출마다 전 종목을 다시 정렬 → O(n log n).
  List<String> _topMoversNaive() {
    final codes = List<String>.from(store.orderedCodes);
    codes.sort((a, b) {
      final byRate =
          store.quoteOf(b).changeRate.compareTo(store.quoteOf(a).changeRate);
      if (byRate != 0) return byRate;
      return a.compareTo(b);
    });
    return codes.take(20).toList(growable: false);
  }

  void dispose() {
    _coalescer?.dispose();
    _batchSub?.cancel();
    _errorSub?.cancel();
    summary.dispose();
    filter.dispose();
    _repo.dispose();
  }
}
