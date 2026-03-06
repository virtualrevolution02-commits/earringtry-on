import 'package:flutter/foundation.dart';
import '../models/earring_model.dart';
import '../services/api_service.dart';
import '../services/face_tracker_service.dart';

/// Workflow states for the AR try-on experience.
enum ARWorkflowState {
  initializing,
  cameraReady,
  faceDetected,
  earDetected,
  earringSelected,
}

/// Global state provider for the AR try-on experience.
class ARProvider extends ChangeNotifier {
  ARWorkflowState _workflowState = ARWorkflowState.initializing;
  EarringModel? _selectedEarring;
  List<EarringModel> _earrings = [];
  List<String> _wishlist = [];
  bool _isLoading = false;
  String? _error;

  // Face tracking data
  List<Map<String, double>> _landmarks = [];
  double _imageWidth = 0;
  double _imageHeight = 0;
  double? _leftEarX;
  double? _leftEarY;
  double? _rightEarX;
  double? _rightEarY;

  // UI toggles
  bool _showMesh = true; // Enable for debugging
  bool _isCapturing = false;

  // Getters
  ARWorkflowState get workflowState => _workflowState;
  EarringModel? get selectedEarring => _selectedEarring;
  List<EarringModel> get earrings => _earrings;
  List<String> get wishlist => _wishlist;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, double>> get landmarks => _landmarks;
  double get imageWidth => _imageWidth;
  double get imageHeight => _imageHeight;
  double? get leftEarX => _leftEarX;
  double? get leftEarY => _leftEarY;
  double? get rightEarX => _rightEarX;
  double? get rightEarY => _rightEarY;
  bool get showMesh => _showMesh;
  bool get isCapturing => _isCapturing;

  bool get isFaceDetected =>
      _workflowState == ARWorkflowState.faceDetected ||
      _workflowState == ARWorkflowState.earDetected ||
      _workflowState == ARWorkflowState.earringSelected;

  bool get isEarDetected =>
      _workflowState == ARWorkflowState.earDetected ||
      _workflowState == ARWorkflowState.earringSelected;

  final ApiService _apiService = ApiService();

  /// Load earring catalog from backend (fallback to local list).
  Future<void> loadEarrings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _earrings = await _apiService.getEarrings();
    } catch (e) {
      _earrings = kFallbackEarrings;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update face tracking data from the face tracker pipeline.
  void updateFaceTrackResult(FaceTrackResult result) {
    _landmarks = result.landmarks;
    _imageWidth = result.imageWidth;
    _imageHeight = result.imageHeight;

    if (result.faceDetected) {
      if (_workflowState == ARWorkflowState.cameraReady) {
        _workflowState = ARWorkflowState.faceDetected;
      }

      _leftEarX = result.leftEarX;
      _leftEarY = result.leftEarY;
      _rightEarX = result.rightEarX;
      _rightEarY = result.rightEarY;

      if (result.earDetected) {
        if (_workflowState == ARWorkflowState.faceDetected) {
          _workflowState = ARWorkflowState.earDetected;
        }
      }
    } else {
      if (_workflowState == ARWorkflowState.faceDetected || 
          _workflowState == ARWorkflowState.earDetected) {
        _workflowState = ARWorkflowState.cameraReady;
      }
      _landmarks = [];
      _leftEarX = null;
      _leftEarY = null;
      _rightEarX = null;
      _rightEarY = null;
    }

    notifyListeners();
  }

  /// Select an earring from the carousel.
  void selectEarring(EarringModel earring) {
    _selectedEarring = earring;
    _workflowState = ARWorkflowState.earringSelected;
    notifyListeners();
    _apiService.trackTryOn(earring.id).catchError((_) {});
  }

  /// Toggle wishlist item.
  Future<void> toggleWishlist(String earringId) async {
    if (_wishlist.contains(earringId)) {
      _wishlist.remove(earringId);
    } else {
      _wishlist.add(earringId);
      await _apiService.addToWishlist(earringId).catchError((_) {});
    }
    notifyListeners();
  }

  bool isInWishlist(String earringId) => _wishlist.contains(earringId);

  void toggleMesh() {
    _showMesh = !_showMesh;
    notifyListeners();
  }

  void setCapturing(bool value) {
    _isCapturing = value;
    notifyListeners();
  }

  void setCameraReady() {
    if (_workflowState == ARWorkflowState.initializing) {
      _workflowState = ARWorkflowState.cameraReady;
      notifyListeners();
    }
  }
}
