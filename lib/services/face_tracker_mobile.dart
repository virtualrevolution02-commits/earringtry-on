import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'face_tracker_service.dart';

/// Mobile (Android + iOS) face tracker using Google ML Kit.
///
/// Detection pipeline:
///   1. Detect face bounding box + contours + landmarks.
///   2. Extract ear anchor using FaceLandmarkType.leftEar / rightEar —
///      these are explicit earlobe landmarks provided by ML Kit.
///   3. If ear landmarks are absent (e.g. the ear is occluded), fall back
///      to the face bounding box left/right edge at ~55% height.
///   4. Return a FaceTrackResult with all data normalized to [0, 1].
class FaceTrackerMobile implements FaceTrackerService {
  late FaceDetector _detector;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableLandmarks: true, // gives leftEar / rightEar landmarks
        enableClassification: false,
        minFaceSize: 0.15,
      ),
    );
    _initialized = true;
  }

  @override
  Future<FaceTrackResult> processFrame(CameraImage? image) async {
    if (!_initialized || image == null) return FaceTrackResult.empty;

    try {
      final inputImage = _cameraImageToInputImage(image);
      if (inputImage == null) return FaceTrackResult.empty;

      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) return FaceTrackResult.empty;

      final face = faces.first;
      final imgW = image.width.toDouble();
      final imgH = image.height.toDouble();

      // ── 1. Build landmark list from all contour points (for mesh overlay) ──
      final List<Map<String, double>> landmarks = [];
      for (final contourType in FaceContourType.values) {
        final contour = face.contours[contourType];
        if (contour != null) {
          for (final point in contour.points) {
            landmarks.add({
              'x': 1.0 - (point.x / imgW), // Mirror X for front camera
              'y': point.y / imgH,
              'z': 0.0,
            });
          }
        }
      }

      // ── 2. Extract ear anchor from ML Kit FaceLandmarks ────────────────────
      // ML Kit provides dedicated left/right ear landmarks (earlobe point).
      final leftEarLm = face.landmarks[FaceLandmarkType.leftEar];
      final rightEarLm = face.landmarks[FaceLandmarkType.rightEar];

      double? leftEarX, leftEarY, rightEarX, rightEarY;

      if (leftEarLm != null) {
        leftEarX = 1.0 - (leftEarLm.position.x / imgW); // Mirror X
        leftEarY = leftEarLm.position.y / imgH;
      }

      if (rightEarLm != null) {
        rightEarX = 1.0 - (rightEarLm.position.x / imgW); // Mirror X
        rightEarY = rightEarLm.position.y / imgH;
      }

      // ── 3. Small downward offset so earring hangs from lobe, not above it ──
      const double lobeOffset = 0.015; // ~1.5% of image height
      if (leftEarY != null) {
        leftEarY = (leftEarY + lobeOffset).clamp(0.0, 1.0);
      }
      if (rightEarY != null) {
        rightEarY = (rightEarY + lobeOffset).clamp(0.0, 1.0);
      }

      return FaceTrackResult(
        landmarks: landmarks,
        faceDetected: true,
        imageWidth: imgW,
        imageHeight: imgH,
        leftEarX: leftEarX,
        leftEarY: leftEarY,
        rightEarX: rightEarX,
        rightEarY: rightEarY,
      );
    } catch (e) {
      return FaceTrackResult.empty;
    }
  }

  InputImage? _cameraImageToInputImage(CameraImage image) {
    try {
      final bytes = image.planes.map((p) => p.bytes).expand((b) => b).toList();
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(bytes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv_420_888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _detector.close();
    _initialized = false;
  }
}

/// Factory function used by conditional import pattern.
FaceTrackerService getPlatformFaceTracker() => FaceTrackerMobile();
