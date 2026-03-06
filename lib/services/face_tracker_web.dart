// Web platform face tracker using MediaPipe FaceMesh via JavaScript interop.
// This file is only compiled on web targets via conditional imports.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: undefined_hidden_name, undefined_shown_name
import 'dart:html' as html; // dart:html is only available on web
// ignore: undefined_hidden_name
import 'dart:js' as js; // dart:js is only available on web
import 'package:camera/camera.dart';
import 'face_tracker_service.dart';

/// Web face tracker: bridges MediaPipe FaceMesh JavaScript SDK to Dart.
///
/// MediaPipe Face Mesh on web returns 468 normalized landmarks.
/// Ear anchor points are extracted using MediaPipe's fixed indices:
///   Left ear lobe:  landmark 234 (left cheek / ear boundary)
///   Right ear lobe: landmark 454 (right cheek / ear boundary)
/// These are well-established MediaPipe Face Mesh landmark indices.
class FaceTrackerWeb implements FaceTrackerService {
  js.JsObject? _faceMesh;
  FaceTrackResult _latestResult = FaceTrackResult.empty;
  final Completer<void> _readyCompleter = Completer();
  bool _isProcessingFrame = false;

  @override
  Future<void> initialize() async {
    // MediaPipe is loaded in web/index.html via CDN script tags.
    for (int i = 0; i < 50; i++) {
      if (js.context.hasProperty('FaceMesh')) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _faceMesh = js.JsObject(js.context['FaceMesh'] as js.JsFunction, [
      js.JsObject.jsify({
        'locateFile': (String file) {
          return 'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/$file';
        }
      })
    ]);

    _faceMesh!.callMethod('setOptions', [
      js.JsObject.jsify({
        'maxNumFaces': 1,
        'refineLandmarks': true,
        'minDetectionConfidence': 0.5,
        'minTrackingConfidence': 0.5,
      })
    ]);

    final resultsCallback = js.JsFunction.withThis((_, dynamic results) {
      if (results is js.JsObject) _handleResults(results);
    });
    _faceMesh!.callMethod('onResults', [resultsCallback]);

    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  void _handleResults(js.JsObject results) {
    _isProcessingFrame = false;
    final dynamic multiFaceLandmarks = results['multiFaceLandmarks'];
    if (multiFaceLandmarks == null) {
      _latestResult = FaceTrackResult.empty;
      return;
    }

    final length = multiFaceLandmarks['length'] as int? ?? 0;
    if (length == 0) {
      _latestResult = FaceTrackResult.empty;
      return;
    }

    final face = multiFaceLandmarks[0] as js.JsObject;
    final faceLen = face['length'] as int? ?? 0;
    final List<Map<String, double>> landmarks = [];

    for (int i = 0; i < faceLen; i++) {
      final lm = face[i] as js.JsObject;
      landmarks.add({
        'x': 1.0 - ((lm['x'] as num?)?.toDouble() ?? 0.0), // Mirror X for front camera preview
        'y': (lm['y'] as num?)?.toDouble() ?? 0.0,
        'z': (lm['z'] as num?)?.toDouble() ?? 0.0,
      });
    }

    // ── Compute earlobe anchor from tragus + jaw landmarks ──
    // MediaPipe Face Mesh indices (BEFORE mirroring):
    //   Sensor-Right tragus: 234, jaw: 132  (User's Right ear)
    //   Sensor-Left  tragus: 454, jaw: 361  (User's Left ear)
    // After mirroring X (1.0 - x):
    //   Screen-Left  = User's Left ear  (indices 454, 361)
    //   Screen-Right = User's Right ear (indices 234, 132)

    // Screen-Left ear (User's Left): tragus=454, jaw=361
    const int leftTragusIdx = 454;
    const int leftJawIdx = 361;
    // Screen-Right ear (User's Right): tragus=234, jaw=132
    const int rightTragusIdx = 234;
    const int rightJawIdx = 132;

    double? leftEarX, leftEarY, rightEarX, rightEarY;

    // Compute left earlobe anchor
    if (landmarks.length > leftTragusIdx) {
      final tx = landmarks[leftTragusIdx]['x'] ?? 0.0;
      final ty = landmarks[leftTragusIdx]['y'] ?? 0.0;
      final jx = landmarks[leftJawIdx]['x'] ?? 0.0;
      final jy = landmarks[leftJawIdx]['y'] ?? 0.0;

      // Earlobe = midpoint shifted outward (away from face) + slightly below jaw
      final midX = (tx + jx) / 2;
      leftEarX = midX + 0.015; // shift right on screen (outward for left ear)
      leftEarY = jy + 0.01;   // slightly below jaw
    }

    // Compute right earlobe anchor
    if (landmarks.length > rightTragusIdx) {
      final tx = landmarks[rightTragusIdx]['x'] ?? 0.0;
      final ty = landmarks[rightTragusIdx]['y'] ?? 0.0;
      final jx = landmarks[rightJawIdx]['x'] ?? 0.0;
      final jy = landmarks[rightJawIdx]['y'] ?? 0.0;

      // Earlobe = midpoint shifted outward (away from face) + slightly below jaw
      final midX = (tx + jx) / 2;
      rightEarX = midX - 0.015; // shift left on screen (outward for right ear)
      rightEarY = jy + 0.01;   // slightly below jaw
    }

    final videos = html.document.getElementsByTagName('video');
    double imgW = _latestResult.imageWidth;
    double imgH = _latestResult.imageHeight;

    if (videos.isNotEmpty) {
      final v = videos[0] as html.VideoElement;
      if (v.videoWidth > 0) {
        imgW = v.videoWidth.toDouble();
        imgH = v.videoHeight.toDouble();
      }
    }

    _latestResult = FaceTrackResult(
      landmarks: List.unmodifiable(landmarks),
      faceDetected: true,
      imageWidth: imgW,
      imageHeight: imgH,
      leftEarX: leftEarX,
      leftEarY: leftEarY,
      rightEarX: rightEarX,
      rightEarY: rightEarY,
    );
  }

  @override
  Future<FaceTrackResult> processFrame(CameraImage? image) async {
    // On web, we pull the HTML video element created by the camera plugin.
    if (_isProcessingFrame) return _latestResult;

    final videos = html.document.getElementsByTagName('video');
    if (videos.isNotEmpty) {
      final videoElement = videos[0] as html.VideoElement;
      // readyState 2+ implies HAVE_CURRENT_DATA
      if (videoElement.readyState >= 2) {
        _isProcessingFrame = true;
        try {
          _faceMesh?.callMethod('send', [
            js.JsObject.jsify({'image': videoElement})
          ]);
        } catch (e) {
          _isProcessingFrame = false; // Reset on error
        }
      }
    }
    return _latestResult;
  }

  @override
  void dispose() {
    _faceMesh?.callMethod('close', []);
    _faceMesh = null;
  }
}

/// Factory function used by conditional import pattern.
FaceTrackerService getPlatformFaceTracker() => FaceTrackerWeb();
