import '../../../../seed/market_feed.dart';
import '../../../../seed/market_models.dart';

/// 시세 소스 추상(정합성 계층 테스트용 DI 경계).
///
/// repository는 이 인터페이스에만 의존하므로, 테스트에서 임의의 tick/에러를
/// 주입하는 fake로 갈아끼울 수 있다.
abstract class TickSource {
  List<QuoteSnapshotEntry> initialSnapshot();
  Stream<List<QuoteTick>> get ticks;
  void start();
  void dispose();
}

/// seed `MarketFeed` 를 감싸는 유일한 지점.
///
/// seed(외부 소스)와 닿는 코드를 여기 한 곳으로 격리한다. 상위 계층은 seed 타입을
/// 직접 import 하지 않고 이 datasource(그리고 repository)를 통해서만 접근한다.
///
/// 벤치마크를 위해 [feed] 를 주입할 수 있게 하여, 결정론적 [pump] 시나리오를
/// 동일 seed로 재현한다.
class MarketFeedDataSource implements TickSource {
  MarketFeedDataSource({MarketFeed? feed}) : _feed = feed ?? MarketFeed();

  final MarketFeed _feed;

  List<SymbolInfo> get symbols => _feed.symbols;

  @override
  List<QuoteSnapshotEntry> initialSnapshot() => _feed.initialSnapshot();

  @override
  Stream<List<QuoteTick>> get ticks => _feed.ticks;

  @override
  void start() => _feed.start();

  /// 결정론적 벤치/테스트용. 반드시 [ticks] 구독 이후 호출.
  void pump([int count = 1]) => _feed.pump(count);

  void stop() => _feed.stop();

  @override
  void dispose() => _feed.dispose();
}
