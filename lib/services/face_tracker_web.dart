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

    // MediaPipe Face Mesh detailed ear indices (lobe area)
    // After mirroring X:
    // User Right ear (234) -> Results in smaller X -> Screen Left
    // User Left ear (454) -> Results in larger X -> Screen Right
    const int leftLobeIdx = 234; 
    const int rightLobeIdx = 454;
    
    // Slight downward offset for hanging effect
    const double verticalLobeOffset = 0.025;

    double? leftEarX, leftEarY, rightEarX, rightEarY;

    if (landmarks.length > leftLobeIdx) {
      leftEarX = landmarks[leftLobeIdx]['x'];
      leftEarY = (landmarks[leftLobeIdx]['y'] ?? 0.0) + verticalLobeOffset;
    }
    if (landmarks.length > rightLobeIdx) {
      rightEarX = landmarks[rightLobeIdx]['x'];
      rightEarY = (landmarks[rightLobeIdx]['y'] ?? 0.0) + verticalLobeOffset;
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
