import 'dart:math';
import 'package:flutter/scheduler.dart';

/// AnimationEngine — manages realistic earring physics.
/// Uses multiple sine waves to simulate natural "lifelike" movement.
class AnimationEngine {
  Ticker? _ticker;
  double _swingAngle = 0.0;
  double _scaleFactor = 1.0;

  final void Function(double angle, double scale) onUpdate;

  AnimationEngine({required this.onUpdate});

  void start(TickerProvider vsync) {
    _ticker = vsync.createTicker((elapsed) {
      final t = elapsed.inMilliseconds / 1000.0;
      
      // Compound Harmonic Motion for the swing:
      // Primary slow swing + faster subtle jitter = more natural movement.
      final primarySwing = sin(t * 1.5) * 0.08;
      final microJitter = sin(t * 4.0) * 0.015;
      _swingAngle = primarySwing + microJitter;

      // Subtle "breathing" scale effect (±2% size change)
      _scaleFactor = 1.0 + (sin(t * 0.8) * 0.02);

      onUpdate(_swingAngle, _scaleFactor);
    });
    _ticker!.start();
  }

  void stop() {
    _ticker?.stop();
    _swingAngle = 0.0;
    _scaleFactor = 1.0;
  }

  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }

  double get currentAngle => _swingAngle;
  double get currentScale => _scaleFactor;
}
