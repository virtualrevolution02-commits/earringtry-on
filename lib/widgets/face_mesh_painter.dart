import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Renders the face mesh wireframe/points on top of the camera feed.
/// On web, landmarks are normalized [0,1] and the video fills the container,
/// so we simply multiply by screen dimensions.
/// On mobile (with FittedBox), we apply BoxFit.cover math.
class FaceMeshPainter extends CustomPainter {
  final List<Map<String, double>> landmarks;
  final Size previewSize;
  final double? imgW;
  final double? imgH;

  FaceMeshPainter({
    required this.landmarks,
    required this.previewSize,
    this.imgW,
    this.imgH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final dotPaint = Paint()
      ..color = const Color(0xFFC9A84C).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final screenW = size.width;
    final screenH = size.height;

    if (kIsWeb) {
      // On web: landmarks are [0,1] and video fills the widget via CSS.
      // Direct mapping: normalized → screen pixels.
      for (final lm in landmarks) {
        final x = (lm['x'] ?? 0) * screenW;
        final y = (lm['y'] ?? 0) * screenH;
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    } else {
      // On mobile: apply BoxFit.cover transform
      if (imgW == null || imgH == null || imgW == 0) return;

      final double scale = (screenW / imgW! > screenH / imgH!)
          ? screenW / imgW!
          : screenH / imgH!;

      final double offsetX = (screenW - imgW! * scale) / 2;
      final double offsetY = (screenH - imgH! * scale) / 2;

      for (final lm in landmarks) {
        final nx = lm['x'] ?? 0;
        final ny = lm['y'] ?? 0;
        final x = (nx * imgW! * scale) + offsetX;
        final y = (ny * imgH! * scale) + offsetY;
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(FaceMeshPainter oldDelegate) => true;
}
