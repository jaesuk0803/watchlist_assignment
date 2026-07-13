import 'package:flutter/material.dart';

import '../formatters.dart';
import '../view_models/quote_vm.dart';

/// 벤치마크용 rebuild 카운터(핫패스 오버헤드는 int 증가 1회뿐).
/// PERF.md의 "rebuild 범위 축소"를 결정론적으로 재는 데 쓴다.
class QuoteRowMetrics {
  static int builds = 0;
  static void reset() => builds = 0;
}

/// 등락 방향별 색상(국내 관례: 상승 빨강 / 하락 파랑 / 보합 회색).
Color directionColor(PriceDirection direction) => switch (direction) {
      PriceDirection.up => const Color(0xFFD32F2F),
      PriceDirection.down => const Color(0xFF1976D2),
      PriceDirection.flat => const Color(0xFF757575),
    };

/// 목록 행 UI(공유). A/B/C 후보 공통으로 이 위젯을 쓴다 — 성능 차이가 전파
/// 방식에서만 나오도록 UI/페인팅을 동일하게 유지한다.
///
/// 고정 높이 + `RepaintBoundary`(호출부에서 감쌈)로 행 단위 페인트 격리.
class QuoteRow extends StatelessWidget {
  const QuoteRow({super.key, required this.vm, this.onTap});

  static const double height = 60;

  final QuoteVM vm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    QuoteRowMetrics.builds++;
    final color = directionColor(vm.direction);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vm.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (vm.isHalted) ...[
                          const SizedBox(width: 6),
                          const _HaltBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vm.code,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  Formatters.thousands(vm.price),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: vm.isHalted ? const Color(0xFF9E9E9E) : color,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      Formatters.signedPercent(vm.changeRate),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.thousands(vm.dayVolume),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HaltBadge extends StatelessWidget {
  const _HaltBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: const Text(
        '정지',
        style: TextStyle(fontSize: 10, color: Color(0xFF616161)),
      ),
    );
  }
}
