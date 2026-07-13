import '../domain/entities/connection_status.dart';

/// 요약 영역(표시 종목 수 · 시총 합계 · Top-20 · 연결상태) 스냅샷.
class SummaryState {
  const SummaryState({
    required this.displayedCount,
    required this.totalMarketCap,
    required this.topMoverCodes,
    required this.connection,
  });

  const SummaryState.empty()
      : displayedCount = 0,
        totalMarketCap = 0,
        topMoverCodes = const [],
        connection = ConnectionStatus.live;

  /// 표시 중 종목 수(필터 통과 수, 없으면 전체).
  final int displayedCount;

  /// 시총 합계(전체 유니버스 기준).
  final double totalMarketCap;

  /// 등락률 Top-20 종목코드(내림차순).
  final List<String> topMoverCodes;

  final ConnectionStatus connection;
}
