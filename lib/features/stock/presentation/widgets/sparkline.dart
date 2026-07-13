import 'package:flutter/material.dart';

/// 최근 N개 체결가를 잇는 간단한 스파크라인.
///
/// 히스토리 버퍼는 상세 화면 state에서 **고정 길이 링버퍼**로 유지(무한 증가 방지).
/// `CustomPainter` 로 그리되 `shouldRepaint` 로 값이 바뀔 때만 다시 그린다.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.points, this.color});

  final List<double> points;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(double.infinity, 120),
        painter: _SparklinePainter(
          points: points,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var min = points.first;
    var max = points.first;
    for (final p in points) {
      if (p < min) min = p;
      if (p > max) max = p;
    }
    final range = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
    final dx = size.width / (points.length - 1);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = dx * i;
      final y = size.height - ((points[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      !identical(old.points, points) || old.color != color;
}
