/// 전파 방식 후보. `--dart-define=CANDIDATE=a|b|c` 로 선택.
///
/// - [a] setState 전체 rebuild (baseline / PERF.md before)
/// - [b] 행별 ValueNotifier (채택 후보 / after)
/// - [c] Riverpod family + select (기각 대안, 비교용)
enum Candidate {
  a,
  b,
  c;

  static Candidate fromEnv() {
    const value = String.fromEnvironment('CANDIDATE', defaultValue: 'b');
    return switch (value) {
      'a' => Candidate.a,
      'c' => Candidate.c,
      _ => Candidate.b,
    };
  }

  String get label => switch (this) {
        Candidate.a => 'A · setState(baseline)',
        Candidate.b => 'B · ValueNotifier',
        Candidate.c => 'C · Riverpod',
      };
}
