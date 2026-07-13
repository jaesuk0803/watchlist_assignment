/// 한글 초성 추출/판별 유틸.
///
/// 라이브러리 대신 직접 구현한다(근거: 규칙이 단순·고정이고 의존성 없이 결정론적,
/// 면접에서 동작을 설명하기 쉬움 — DESIGN.md 참조).
///
/// 완성형 한글 음절 유니코드: 0xAC00(가) ~ 0xD7A3(힣).
/// 음절 index = code - 0xAC00 이며, 초성 index = index ~/ (21*28).
class Chosung {
  const Chosung._();

  static const List<String> table = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
  ];

  static const int _syllableBase = 0xAC00;
  static const int _syllableEnd = 0xD7A3;
  static const int _blockSize = 21 * 28; // 중성 21 × 종성 28

  static final Set<int> _choseongRunes = {
    for (final c in table) c.runes.first,
  };

  /// 문자열의 각 완성형 음절을 초성으로 바꾼 문자열.
  /// 한글이 아닌 문자는 그대로 유지한다.
  static String extract(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= _syllableBase && rune <= _syllableEnd) {
        final index = (rune - _syllableBase) ~/ _blockSize;
        buffer.write(table[index]);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// [query] 가 초성 문자로만 이루어졌는지(초성 검색인지) 판별.
  static bool isChoseongQuery(String query) {
    if (query.isEmpty) return false;
    for (final rune in query.runes) {
      if (!_choseongRunes.contains(rune)) return false;
    }
    return true;
  }
}
