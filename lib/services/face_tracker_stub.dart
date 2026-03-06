import 'package:camera/camera.dart';
import 'face_tracker_service.dart';

/// Stub implementation — used on unsupported platforms.
class FaceTrackerStub implements FaceTrackerService {
  @override
  Future<void> initialize() async {}

  @override
  Future<FaceTrackResult> processFrame(CameraImage? image) async =>
      FaceTrackResult.empty;

  @override
  void dispose() {}
}

FaceTrackerService getPlatformFaceTracker() => FaceTrackerStub();
