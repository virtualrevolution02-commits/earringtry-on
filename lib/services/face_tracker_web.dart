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
    html.window.console.log('Initializing FaceTrackerWeb...');
    
    // MediaPipe is loaded in web/index.html via CDN script tags.
    for (int i = 0; i < 50; i++) {
      if (js.context.hasProperty('FaceMesh')) {
        html.window.console.log('FaceMesh class found in window context');
        break;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      _faceMesh = js.JsObject(js.context['FaceMesh'] as js.JsFunction, [
        js.JsObject.jsify({
          'locateFile': (String file) {
            // Using a specific version to match script tags
            return 'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4/$file';
          }
        })
      ]);

      _faceMesh!.callMethod('setOptions', [
        js.JsObject.jsify({
          'maxNumFaces': 1,
          'refineLandmarks': true,
          'minDetectionConfidence': 0.5,
          'minTrackingConfidence': 0.5,
          'selfieMode': true, // Use selfieMode to let MediaPipe handle mirroring internally if possible
        })
      ]);

      final resultsCallback = js.JsFunction.withThis((_, dynamic results) {
        if (results != null) {
          _handleResults(js.JsObject.fromBrowserObject(results));
        }
      });
      _faceMesh!.callMethod('onResults', [resultsCallback]);
      
      html.window.console.log('FaceMesh initialized successfully');
    } catch (e) {
      html.window.console.error('FaceMesh init error: $e');
    }

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

    // Safely get length and first face
    int length = 0;
    try {
      length = multiFaceLandmarks['length'] as int? ?? 0;
    } catch (_) {
      // Fallback if it's a direct JS array proxy
      final List l = multiFaceLandmarks as List;
      length = l.length;
    }

    if (length == 0) {
      _latestResult = FaceTrackResult.empty;
      return;
    }

    final dynamic faceRaw = multiFaceLandmarks[0];
    final js.JsObject face = (faceRaw is js.JsObject) 
        ? faceRaw 
        : js.JsObject.fromBrowserObject(faceRaw);

    int faceLen = 0;
    try {
      faceLen = face['length'] as int? ?? 0;
    } catch (_) {
      faceLen = (faceRaw as List).length;
    }

    final List<Map<String, double>> landmarks = [];
    for (int i = 0; i < faceLen; i++) {
      final lm = face[i] as js.JsObject;
      // We rely on 'selfieMode: true' in setOptions for mirroring, 
      // but if that doesn't work, we'll need to manually check.
      // For now, let's keep manual mirroring for maximum consistency with the preview.
      landmarks.add({
        'x': 1.0 - ((lm['x'] as num?)?.toDouble() ?? 0.0),
        'y': (lm['y'] as num?)?.toDouble() ?? 0.0,
        'z': (lm['z'] as num?)?.toDouble() ?? 0.0,
      });
    }

    // Better Ear Positions:
    // User RIGHT (Viewer LEFT in mirrored view): index 234 (tragus), 132 (lower ear boundary)
    // User LEFT (Viewer RIGHT in mirrored view): index 454 (tragus), 361 (lower ear boundary)
    const int leftTragusIdx = 234; 
    const int rightTragusIdx = 454;
    const int leftLobeLowerIdx = 132;
    const int rightLobeLowerIdx = 361;

    double? leftEarX, leftEarY, rightEarX, rightEarY;

    if (landmarks.length > leftTragusIdx && landmarks.length > leftLobeLowerIdx) {
      final t = landmarks[leftTragusIdx];
      final l = landmarks[leftLobeLowerIdx];
      // The lobe is usually slightly below the tragus and near the lower ear boundary
      leftEarX = t['x']! * 0.7 + l['x']! * 0.3;
      leftEarY = t['y']! * 0.5 + l['y']! * 0.5 + 0.01; 
    }
    
    if (landmarks.length > rightTragusIdx && landmarks.length > rightLobeLowerIdx) {
      final t = landmarks[rightTragusIdx];
      final l = landmarks[rightLobeLowerIdx];
      rightEarX = t['x']! * 0.7 + l['x']! * 0.3;
      rightEarY = t['y']! * 0.5 + l['y']! * 0.5 + 0.01;
    }

    // Image dimensions
    final videos = html.document.getElementsByTagName('video');
    double imgW = _latestResult.imageWidth;
    double imgH = _latestResult.imageHeight;

    if (videos.isNotEmpty) {
      html.VideoElement? cameraVideo;
      for (int i = 0; i < videos.length; i++) {
        final v = videos[i] as html.VideoElement;
        if (v.readyState >= 2 && v.videoWidth > 0 && !v.paused) {
          cameraVideo = v;
          break;
        }
      }
      
      final v = cameraVideo ?? videos[0] as html.VideoElement;
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
      html.VideoElement? cameraVideo;
      for (int i = 0; i < videos.length; i++) {
        final v = videos[i] as html.VideoElement;
        // Prefer the playing video element
        if (v.readyState >= 2 && !v.paused) {
          cameraVideo = v;
          break;
        }
      }

      final videoElement = cameraVideo ?? videos[0] as html.VideoElement;
      if (videoElement.readyState >= 2) {
        _isProcessingFrame = true;
        try {
          _faceMesh?.callMethod('send', [
            js.JsObject.jsify({'image': videoElement})
          ]);
        } catch (e) {
          _isProcessingFrame = false;
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
