import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../providers/ar_provider.dart';
import '../services/animation_engine.dart';

/// Positions 3D (GLB) or 2D (PNG/GIF) earring at the detected ear anchor points.
class EarringOverlay extends StatefulWidget {
  const EarringOverlay({
    super.key,
  });

  @override
  State<EarringOverlay> createState() => _EarringOverlayState();
}

class _EarringOverlayState extends State<EarringOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationEngine _animationEngine;
  double _swingAngle = 0.0;
  double _scaleFactor = 1.0;
  double? _lastLeftX;
  double? _lastRightX;

  @override
  void initState() {
    super.initState();
    _animationEngine = AnimationEngine(
      onUpdate: (angle, scale) {
        if (mounted) {
          setState(() {
            _swingAngle = angle;
            _scaleFactor = scale;
          });
        }
      },
    );
    _animationEngine.start(this);
  }

  @override
  void dispose() {
    _animationEngine.dispose();
    super.dispose();
  }

  void _processMovement(double? currentLeftX, double? currentRightX) {
    if (currentLeftX != null && _lastLeftX != null) {
      final delta = currentLeftX - _lastLeftX!;
      if (delta.abs() > 0.001) {
        _animationEngine.nudge(delta);
      }
    } else if (currentRightX != null && _lastRightX != null) {
      final delta = currentRightX - _lastRightX!;
      if (delta.abs() > 0.001) {
        _animationEngine.nudge(delta);
      }
    }
    _lastLeftX = currentLeftX;
    _lastRightX = currentRightX;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentW = constraints.maxWidth;
        final parentH = constraints.maxHeight;

        return Consumer<ARProvider>(
          builder: (context, provider, _) {
            final earring = provider.selectedEarring;
            if (earring == null) return const SizedBox.shrink();

            final showLeft = provider.leftEarX != null;
            final showRight = provider.rightEarX != null;

            if (!showLeft && !showRight) return const SizedBox.shrink();

            // React to movement
            _processMovement(provider.leftEarX, provider.rightEarX);

            // Earring visual size (relative to a 720p baseline, scaled by parent)
            // We scale the base size by parentH / 720 or similar if needed, 
            // but since it's already in the FittedBox, we can use absolute-looking pixels 
            // that are relative to the camera resolution.
            const double baseW = 75.0;
            const double baseH = 115.0;

            final is3D = earring.modelUrl.toLowerCase().endsWith('.glb') || 
                         earring.imageUrl.toLowerCase().endsWith('.glb');

            return Stack(
              children: [
                if (showLeft)
                  _buildEarringAt(
                    earring: earring,
                    is3D: is3D,
                    left: (provider.leftEarX! * parentW) - (baseW * _scaleFactor) / 2,
                    top: provider.leftEarY! * parentH,
                    width: baseW * _scaleFactor,
                    height: baseH * _scaleFactor,
                    perspectiveRotation: (provider.leftEarX! - 0.5) * 0.4, 
                  ),
                if (showRight)
                  _buildEarringAt(
                    earring: earring,
                    is3D: is3D,
                    left: (provider.rightEarX! * parentW) - (baseW * _scaleFactor) / 2,
                    top: provider.rightEarY! * parentH,
                    width: baseW * _scaleFactor,
                    height: baseH * _scaleFactor,
                    mirrorSwing: true,
                    perspectiveRotation: (provider.rightEarX! - 0.5) * 0.4,
                  ),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildEarringAt({
    required dynamic earring,
    required bool is3D,
    required double left,
    required double top,
    required double width,
    required double height,
    double perspectiveRotation = 0.0,
    bool mirrorSwing = false,
  }) {
    final angle = mirrorSwing ? -_swingAngle : _swingAngle;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateY(is3D ? 0 : perspectiveRotation)
          ..rotateZ(is3D ? 0 : angle),
        child: is3D 
          ? _build3DModel(earring.modelUrl.isNotEmpty ? earring.modelUrl : earring.imageUrl) 
          : _buildEarringImage(earring.imageUrl, width, height),
      ),
    );
  }

  Widget _build3DModel(String modelPath) {
    return SizedBox(
      width: 100,
      height: 100,
      child: ModelViewer(
        backgroundColor: Colors.transparent,
        src: modelPath,
        alt: "AR Earring",
        ar: false,
        autoRotate: true,
        cameraControls: false,
        disableZoom: true,
        loading: Loading.lazy,
      ),
    );
  }

  Widget _buildEarringImage(String imageUrl, double width, double height) {
    final isAsset = !imageUrl.startsWith('http');
    return isAsset
        ? Image.asset(
            imageUrl,
            width: width,
            height: height,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallbackIcon(width, height),
          )
        : Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallbackIcon(width, height),
          );
  }

  Widget _fallbackIcon(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: const Icon(
        Icons.circle,
        color: Color(0xFFC9A84C),
        size: 20,
      ),
    );
  }
}
