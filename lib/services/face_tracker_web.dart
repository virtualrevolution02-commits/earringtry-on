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
    // Wait for the JS helper to be initialized by the window 'load' listener
    for (int i = 0; i < 50; i++) {
      final helper = js.context['FaceMeshHelper'];
      if (helper != null && helper['isLoaded'] == true) {
        html.window.console.log('[Dart] FaceMeshHelper found and loaded');
        break;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  void _handleRawData(dynamic flatData) {
    if (flatData == null) {
      _latestResult = FaceTrackResult.empty;
      return;
    }

    final List<Map<String, double>> landmarks = [];
    // Data is a flat Float32Array: [x,y,z, x,y,z, ...]
    final int count = (flatData['length'] as int) ~/ 3;
    
    for (int i = 0; i < count; i++) {
      landmarks.add({
        'x': (flatData[i * 3] as num).toDouble(),
        'y': (flatData[i * 3 + 1] as num).toDouble(),
        'z': (flatData[i * 3 + 2] as num).toDouble(),
      });
    }

    const int leftTragusIdx = 234; 
    const int rightTragusIdx = 454;
    const int leftLobeLowerIdx = 132;
    const int rightLobeLowerIdx = 361;

    double? leftEarX, leftEarY, rightEarX, rightEarY;

    if (landmarks.length > leftTragusIdx && landmarks.length > leftLobeLowerIdx) {
      final t = landmarks[leftTragusIdx];
      final l = landmarks[leftLobeLowerIdx];
      leftEarX = t['x']! * 0.7 + l['x']! * 0.3;
      leftEarY = t['y']! * 0.5 + l['y']! * 0.5 + 0.01; 
    }
    
    if (landmarks.length > rightTragusIdx && landmarks.length > rightLobeLowerIdx) {
      final t = landmarks[rightTragusIdx];
      final l = landmarks[rightLobeLowerIdx];
      rightEarX = t['x']! * 0.7 + l['x']! * 0.3;
      rightEarY = t['y']! * 0.5 + l['y']! * 0.5 + 0.01;
    }

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
    if (_isProcessingFrame) return _latestResult;

    final helper = js.context['FaceMeshHelper'];
    if (helper == null || helper['isLoaded'] != true) return _latestResult;

    final videos = html.document.getElementsByTagName('video');
    if (videos.isNotEmpty) {
      html.VideoElement? cameraVideo;
      for (int i = 0; i < videos.length; i++) {
        final v = videos[i] as html.VideoElement;
        if (v.readyState >= 2 && !v.paused) {
          cameraVideo = v;
          break;
        }
      }

      final videoElement = cameraVideo ?? videos[0] as html.VideoElement;
      if (videoElement.readyState >= 2) {
        _isProcessingFrame = true;
        try {
          // callMethod 'processImage' returns a Promise
          final dynamic promise = helper.callMethod('processImage', [videoElement]);
          if (promise != null) {
            // Wait for promise resolution
            final results = await html.window.promiseToFuture(promise);
            _handleRawData(results);
          }
        } catch (e) {
          html.window.console.error('[Dart] Error processing frame: $e');
        } finally {
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
