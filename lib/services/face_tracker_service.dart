import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

// Conditional platform import
import 'face_tracker_stub.dart'
    if (dart.library.html) 'face_tracker_web.dart'
    if (dart.library.io) 'face_tracker_mobile.dart';

/// Structured result returned by every face tracker implementation.
/// Carries both the raw landmark list (for mesh drawing) and the
/// already-computed ear anchor positions (normalized [0,1]).
class FaceTrackResult {
  /// All face mesh landmark points, normalized to [0,1].
  final List<Map<String, double>> landmarks;

  /// Whether a face was detected in this frame.
  final bool faceDetected;

  /// The dimensions of the image the landmarks were detected in.
  /// Crucial for aspect ratio calculations.
  final double imageWidth;
  final double imageHeight;

  /// Left earlobe position, normalized [0,1]. Null if not detected.
  final double? leftEarX;
  final double? leftEarY;

  /// Right earlobe position, normalized [0,1]. Null if not detected.
  final double? rightEarX;
  final double? rightEarY;

  const FaceTrackResult({
    this.landmarks = const [],
    this.faceDetected = false,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.leftEarX,
    this.leftEarY,
    this.rightEarX,
    this.rightEarY,
  });

  /// True if at least one ear is detected.
  bool get earDetected => leftEarX != null || rightEarX != null;
  bool get isLeftEarDetected => leftEarX != null;
  bool get isRightEarDetected => rightEarX != null;

  /// Empty result when no face is visible.
  static const empty = FaceTrackResult();
}

/// Abstract interface for face tracking across platforms.
abstract class FaceTrackerService {
  Future<void> initialize();
  Future<FaceTrackResult> processFrame(CameraImage? image);
  void dispose();
}

/// Factory that returns the correct implementation based on platform.
FaceTrackerService createFaceTracker() {
  return getPlatformFaceTracker();
}
