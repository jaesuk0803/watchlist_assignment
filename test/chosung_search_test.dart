import 'package:flutter_test/flutter_test.dart';
import 'package:watchlist_assignment/features/stock/application/search/chosung.dart';
import 'package:watchlist_assignment/features/stock/application/search/symbol_search_index.dart';
import 'package:watchlist_assignment/features/stock/domain/entities/market_kind.dart';
import 'package:watchlist_assignment/features/stock/domain/entities/stock_meta.dart';

StockMeta _meta(String code, String name) => StockMeta(
      code: code,
      name: name,
      market: MarketKind.kospi,
      listedShares: 1000000,
      previousClose: 1000,
    );

void main() {
  group('Chosung', () {
    test('완성형 음절을 초성으로 변환', () {
      expect(Chosung.extract('가온전자'), 'ㄱㅇㅈㅈ');
      expect(Chosung.extract('나래화학'), 'ㄴㄹㅎㅎ');
    });

    test('초성 쿼리 판별', () {
      expect(Chosung.isChoseongQuery('ㄱㅇ'), isTrue);
      expect(Chosung.isChoseongQuery('전자'), isFalse);
      expect(Chosung.isChoseongQuery('000590'), isFalse);
      expect(Chosung.isChoseongQuery(''), isFalse);
    });
  });

  group('SymbolSearchIndex', () {
    final index = SymbolSearchIndex([
      _meta('000001', '가온전자'),
      _meta('000002', '나래화학'),
      _meta('000003', '가온제약'),
      _meta('000590', '다온전자'),
    ]);

    test('초성 검색: ㄱㅇ → 가온전자·가온제약', () {
      final r = index.match('ㄱㅇ');
      expect(r, containsAll(<String>{'000001', '000003'}));
      expect(r, isNot(contains('000002')));
    });

    test('초성 검색: ㄴㄹㅎㅎ → 나래화학', () {
      expect(index.match('ㄴㄹㅎㅎ'), {'000002'});
    });

    test('완성형 부분일치: 전자', () {
      expect(index.match('전자'), containsAll(<String>{'000001', '000590'}));
    });

    test('종목코드 부분일치: 000590', () {
      expect(index.match('000590'), {'000590'});
    });

    test('빈 쿼리는 null(=필터 없음)', () {
      expect(index.match(''), isNull);
      expect(index.match('   '), isNull);
    });
  });
}
