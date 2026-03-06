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

  double _velocity = 0.0;
  double _lastT = 0.0;

  void start(TickerProvider vsync) {
    _ticker = vsync.createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1000000.0;
      if (_lastT == 0) {
        _lastT = t;
        return;
      }
      final dt = t - _lastT;
      _lastT = t;

      // Physics-based Pendulum simulation
      // Restoring force (gravity) proportional to angle
      const double gravity = 9.8;
      const double length = 0.5; // Virtual string length
      const double friction = 1.8; // Air resistance / dampening

      // a = - (g/L) * sin(theta)
      final double acc = -(gravity / length) * sin(_swingAngle);
      
      // Update velocity with dampening
      _velocity += acc * dt;
      _velocity *= (1.0 - friction * dt);

      // Update angle
      _swingAngle += _velocity * dt;

      // Adding a tiny random "wind" or jitter to keep it alive
      if (_swingAngle.abs() < 0.01) {
        _velocity += (Random().nextDouble() - 0.5) * 0.05;
      }

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

  void nudge(double amount) {
    // Inject velocity into the pendulum based on movement
    _velocity += amount * 15.0; // multiplier to make it visible
  }

  double get currentAngle => _swingAngle;
  double get currentScale => _scaleFactor;
}
