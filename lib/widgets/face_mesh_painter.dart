import 'package:flutter/material.dart';

/// MediaPipe Face Mesh ear-region landmark indices.
/// These represent the face contour points closest to the ears.
class EarLandmarkIndices {
  // ── Right ear (user's right, screen-left after mirror) ──
  // Tragus / ear-cheek junction area
  static const int rightTragus = 234;
  // Jawline near right ear
  static const int rightJaw1 = 132;
  static const int rightJaw2 = 58;
  static const int rightJaw3 = 172;
  // Cheek near right ear
  static const int rightCheek1 = 93;
  static const int rightCheek2 = 127;
  static const int rightCheek3 = 162;
  static const int rightTemple = 21;

  // ── Left ear (user's left, screen-right after mirror) ──
  // Tragus / ear-cheek junction area
  static const int leftTragus = 454;
  // Jawline near left ear
  static const int leftJaw1 = 361;
  static const int leftJaw2 = 288;
  static const int leftJaw3 = 397;
  // Cheek near left ear
  static const int leftCheek1 = 323;
  static const int leftCheek2 = 356;
  static const int leftCheek3 = 389;
  static const int leftTemple = 251;

  /// All right-ear region indices
  static const List<int> rightEar = [
    rightTragus, rightJaw1, rightJaw2, rightJaw3,
    rightCheek1, rightCheek2, rightCheek3, rightTemple,
  ];

  /// All left-ear region indices
  static const List<int> leftEar = [
    leftTragus, leftJaw1, leftJaw2, leftJaw3,
    leftCheek1, leftCheek2, leftCheek3, leftTemple,
  ];

  /// All ear-region indices combined
  static const List<int> all = [...rightEar, ...leftEar];
}

class FaceMeshPainter extends CustomPainter {
  final List<Map<String, double>> landmarks;
  final bool showEarDots;

  FaceMeshPainter({
    required this.landmarks,
    this.showEarDots = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    // ── 1. Regular face mesh dots (small, semi-transparent gold) ──
    final dotPaint = Paint()
      ..color = const Color(0xFFC9A84C).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (final lm in landmarks) {
      final nx = lm['x'] ?? 0;
      final ny = lm['y'] ?? 0;
      final x = nx * size.width;
      final y = ny * size.height;
      canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
    }

    if (!showEarDots) return;

    // ── 2. Ear-region landmark dots (larger, bright colored) ──
    final earDotPaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..style = PaintingStyle.fill;

    final earRingPaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Tragus dots (even bigger, different color)
    final tragusPaint = Paint()
      ..color = const Color(0xFFFF4488)
      ..style = PaintingStyle.fill;

    final tragusRingPaint = Paint()
      ..color = const Color(0xFFFF4488).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw the earlobe anchor (computed point) as a cyan crosshair
    final lobeAnchorPaint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..style = PaintingStyle.fill;

    final lobeRingPaint = Paint()
      ..color = const Color(0xFF00FFFF).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final idx in EarLandmarkIndices.all) {
      if (idx >= landmarks.length) continue;
      final lm = landmarks[idx];
      final x = (lm['x'] ?? 0) * size.width;
      final y = (lm['y'] ?? 0) * size.height;

      final isTragus = idx == EarLandmarkIndices.rightTragus ||
                       idx == EarLandmarkIndices.leftTragus;

      if (isTragus) {
        canvas.drawCircle(Offset(x, y), 5.0, tragusPaint);
        canvas.drawCircle(Offset(x, y), 8.0, tragusRingPaint);
      } else {
        canvas.drawCircle(Offset(x, y), 3.5, earDotPaint);
        canvas.drawCircle(Offset(x, y), 6.0, earRingPaint);
      }
    }

    // ── 3. Draw computed earlobe anchor points ──
    // Right earlobe anchor: midpoint of tragus (234) and jaw (132), shifted outward + down
    _drawLobeAnchor(
      canvas, size, 
      EarLandmarkIndices.rightTragus, 
      EarLandmarkIndices.rightJaw1, 
      lobeAnchorPaint, lobeRingPaint,
      isRight: true,
    );

    // Left earlobe anchor: midpoint of tragus (454) and jaw (361), shifted outward + down
    _drawLobeAnchor(
      canvas, size,
      EarLandmarkIndices.leftTragus, 
      EarLandmarkIndices.leftJaw1, 
      lobeAnchorPaint, lobeRingPaint,
      isRight: false,
    );
  }

  void _drawLobeAnchor(
    Canvas canvas, Size size,
    int tragusIdx, int jawIdx,
    Paint dotPaint, Paint ringPaint, {
    required bool isRight,
  }) {
    if (tragusIdx >= landmarks.length || jawIdx >= landmarks.length) return;

    final tragus = landmarks[tragusIdx];
    final jaw = landmarks[jawIdx];

    final tx = (tragus['x'] ?? 0);
    final ty = (tragus['y'] ?? 0);
    final jx = (jaw['x'] ?? 0);
    final jy = (jaw['y'] ?? 0);

    // The earlobe hangs at a point:
    // - X: shifted outward from the midpoint (towards the ear, away from face center)
    // - Y: at the jaw point or slightly below (earlobes hang at jawline level)
    final midX = (tx + jx) / 2;
    final double outwardShift = isRight ? -0.015 : 0.015; // shift away from face center
    final lobeX = midX + outwardShift;
    final lobeY = jy + 0.01; // slightly below jaw point

    final x = lobeX * size.width;
    final y = lobeY * size.height;

    // Draw crosshair
    canvas.drawCircle(Offset(x, y), 6.0, dotPaint);
    canvas.drawCircle(Offset(x, y), 10.0, ringPaint);

    // Draw cross lines
    final crossPaint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x - 12, y), Offset(x + 12, y), crossPaint);
    canvas.drawLine(Offset(x, y - 12), Offset(x, y + 12), crossPaint);
  }

  @override
  bool shouldRepaint(FaceMeshPainter oldDelegate) => true;
}
